import asyncio
import base64
from datetime import datetime, timezone

from supabase import Client

from app.config import Settings
from app.core.enums import ALLOWED_STATUS_TRANSITIONS, ImageSource, JobStatus
from app.core.exceptions import (
    AIProviderError,
    GenerationFailedError,
    InsufficientCreditsError,
    NotFoundError,
    UnauthorizedError,
    ValidationError,
)
from app.core.logging import get_logger
from app.schemas.generation_schema import (
    ORIGIN_SETTINGS_KEY,
    REF_SETTINGS_KEY,
    GenerationCreate,
    GenerationOut,
    MAX_INPUT_IMAGES,
)
from app.services.credit_service import CreditService
from app.services.generation_limit_service import GenerationLimitService
from app.services.pricing_service import (
    estimate_provider_cost_usd,
    get_active_model,
    resolve_generation_pricing,
)
from app.services.storage_service import StorageService
from app.services.tool_service import ToolService
from app.utils.image_transform import fit_to_aspect
logger = get_logger(__name__)

SAFE_FAIL_MESSAGE = "Generation failed. Your credits were refunded."
SAFE_FAIL_NO_REFUND = "Generation failed."


class GenerationService:
    def __init__(
        self,
        db: Client,
        settings: Settings,
        storage: StorageService,
        tools: ToolService,
        credits: CreditService,
    ):
        self.db = db
        self.settings = settings
        self.storage = storage
        self.tools = tools
        self.credits = credits
        self.limits = GenerationLimitService(db, settings)

    async def create(
        self,
        user_id: str,
        payload: GenerationCreate,
        *,
        async_mode: bool = False,
    ) -> GenerationOut:
        if payload.idempotency_key:
            existing = await asyncio.to_thread(
                self._get_by_idempotency, user_id, payload.idempotency_key
            )
            if existing:
                return self._to_out(existing)

        tool = await self.tools.get_by_slug(payload.tool_slug)
        input_paths = self._normalize_input_paths(payload, user_id=user_id, tool=tool)
        pricing = resolve_generation_pricing(tool, self.settings)

        await asyncio.to_thread(
            self.limits.assert_generation_allowed, user_id, pricing.credit_cost
        )

        if pricing.credit_cost > 0:
            balance = await self.credits.get_balance(user_id)
            if balance.balance < pricing.credit_cost:
                raise InsufficientCreditsError("Insufficient credits for this generation")

        input_expires = self.storage.retention_expiry(kind="upload")
        row = await asyncio.to_thread(
            self._insert,
            user_id,
            payload,
            input_paths,
            pricing,
            input_expires,
        )
        await self._charge_generation(row, pricing.credit_cost, tool.slug)

        if async_mode:
            # Already charged once. Worker/background must NOT charge again.
            return self._to_out(await asyncio.to_thread(self._get, row["id"]))

        result = await self.process_generation(row["id"])
        if result.status in {JobStatus.FAILED.value, JobStatus.REFUNDED.value}:
            message = (
                SAFE_FAIL_MESSAGE
                if result.credit_refund_transaction_id
                else SAFE_FAIL_NO_REFUND
            )
            raise GenerationFailedError(message, data=result.model_dump())
        return result

    def _normalize_input_paths(
        self,
        payload: GenerationCreate,
        *,
        user_id: str,
        tool,
    ) -> list[str]:
        raw = list(payload.input_image_urls or [])
        if payload.input_image_url and payload.input_image_url not in raw:
            raw = [payload.input_image_url] + raw
        if not raw:
            raise ValidationError("At least one input image is required")

        min_n = max(1, min(MAX_INPUT_IMAGES, int(getattr(tool, "min_input_images", 1) or 1)))
        max_n = max(min_n, min(MAX_INPUT_IMAGES, int(getattr(tool, "max_input_images", 1) or 1)))
        if len(raw) < min_n:
            raise ValidationError(
                f"This tool requires exactly {min_n} photos"
                if min_n == max_n
                else f"This tool requires at least {min_n} photos"
            )
        if len(raw) > max_n:
            raise ValidationError(f"This tool allows at most {max_n} photos")

        # Together: keep every slot (same photo may be attached again as a ref).
        # Other tools: path-dedupe — extra copies of the same upload aren't useful.
        is_together = getattr(tool, "slug", "") == "together"
        paths: list[str] = []
        seen: set[str] = set()
        for ref in raw:
            path = self.storage.normalize_input_ref(ref, user_id=user_id)
            if is_together:
                paths.append(path)
                continue
            if path in seen:
                continue
            seen.add(path)
            paths.append(path)

        if not is_together and len(paths) < min_n:
            raise ValidationError(f"This tool requires {min_n} distinct photos")
        if is_together and len(paths) < min_n:
            raise ValidationError(f"This tool requires at least {min_n} photos")
        return paths[:max_n]

    async def ensure_can_create(self, user_id: str, tool_slug: str):
        tool = await self.tools.get_by_slug(tool_slug)
        pricing = resolve_generation_pricing(tool, self.settings)
        await asyncio.to_thread(
            self.limits.assert_generation_allowed, user_id, pricing.credit_cost
        )
        if pricing.credit_cost <= 0:
            return tool
        balance = await self.credits.get_balance(user_id)
        if balance.balance < pricing.credit_cost:
            raise InsufficientCreditsError("Insufficient credits for this generation")
        return tool

    async def process_generation(self, generation_id: str) -> GenerationOut:
        """Worker entrypoint: never deducts credits."""
        row = await asyncio.to_thread(self._get, generation_id)
        if row.get("deleted_at"):
            raise NotFoundError("Generation not found")
        if row["status"] == JobStatus.COMPLETED.value:
            return self._to_out(row)
        if row["status"] == JobStatus.REFUNDED.value:
            return self._to_out(row)
        if row["status"] not in {
            JobStatus.PENDING.value,
            JobStatus.PROCESSING.value,
        }:
            return self._to_out(row)

        # Only one worker may claim a pending job. Poll recovery and
        # create_task can both schedule; CAS prevents double BFL spend.
        if row["status"] == JobStatus.PENDING.value:
            claimed = await asyncio.to_thread(self._claim_for_processing, row["id"])
            if not claimed:
                refreshed = await asyncio.to_thread(self._get, generation_id)
                return self._to_out(refreshed)
            row = claimed
        elif row["status"] == JobStatus.PROCESSING.value:
            # Another worker already owns this job (or crash mid-run).
            return self._to_out(row)

        return await self._process(row)

    def _claim_for_processing(self, generation_id: str) -> dict | None:
        """Atomically pending → processing. Returns claimed row or None."""
        now = datetime.now(timezone.utc).isoformat()
        result = (
            self.db.table("generations")
            .update(
                {
                    "status": JobStatus.PROCESSING.value,
                    "started_at": now,
                    "updated_at": now,
                    "error_message": None,
                }
            )
            .eq("id", generation_id)
            .eq("status", JobStatus.PENDING.value)
            .execute()
        )
        if not result.data:
            return None
        return result.data[0]

    async def get_by_id(self, generation_id: str, user_id: str) -> GenerationOut:
        row = await asyncio.to_thread(self._get, generation_id)
        if row.get("deleted_at") or row["user_id"] != user_id:
            raise UnauthorizedError("Not allowed")
        return self._to_out(row)

    async def list_by_user(self, user_id: str, limit: int = 20) -> list[GenerationOut]:
        rows = await asyncio.to_thread(self._list, user_id, limit)
        out: list[GenerationOut] = []
        for row in rows:
            try:
                out.append(self._to_out(row))
            except Exception:
                # One bad/legacy row must never blank the whole History feed.
                logger.exception(
                    "generation_row_skipped id=%s",
                    (row or {}).get("id"),
                )
        return out

    async def soft_delete(self, generation_id: str, user_id: str) -> None:
        """User delete: remove media when safe. NEVER refunds credits."""
        row = await asyncio.to_thread(self._get, generation_id)
        if row["user_id"] != user_id:
            raise UnauthorizedError("Not allowed")
        if row.get("deleted_at"):
            return

        paths_to_delete: list[str] = []
        # Always safe to remove this generation's output.
        if row.get("output_image_url"):
            paths_to_delete.append(row["output_image_url"])
        # Only delete primary input when this is an original upload, not when
        # input is a prior version's output (legacy rows from the retired
        # feedback-iterate feature — parent_generation_id is no longer set on
        # new generations, but may still be present on old rows).
        is_iterate = bool(row.get("parent_generation_id"))
        if not is_iterate and row.get("input_image_url"):
            paths_to_delete.append(row["input_image_url"])
            refs = (row.get("settings") or {}).get(REF_SETTINGS_KEY) or []
            origins = (row.get("settings") or {}).get(ORIGIN_SETTINGS_KEY) or []
            if isinstance(refs, list):
                paths_to_delete.extend(str(p) for p in refs if p)
            if isinstance(origins, list):
                paths_to_delete.extend(str(p) for p in origins if p)

        # Dedup
        seen_del: set[str] = set()
        unique_del: list[str] = []
        for path in paths_to_delete:
            if not path or path in seen_del:
                continue
            seen_del.add(path)
            unique_del.append(path)

        for path in unique_del:
            if path.startswith("http") or path.startswith("assets/"):
                continue
            try:
                await asyncio.to_thread(self.storage.delete_object, path)
            except Exception:
                logger.warning(
                    "storage_delete_failed generation_id=%s path=%s",
                    generation_id,
                    path[:80],
                )

        await asyncio.to_thread(
            self._set,
            generation_id,
            deleted_at=datetime.now(timezone.utc).isoformat(),
            status=row["status"],
        )

    def _insert(
        self,
        user_id: str,
        payload: GenerationCreate,
        input_paths: list[str],
        pricing,
        input_expires,
    ) -> dict:
        source = (
            payload.source.value
            if isinstance(payload.source, ImageSource)
            else str(payload.source)
        )
        settings = dict(payload.settings or {})
        # Strip any client-supplied reserved keys, then store refs server-side only.
        settings.pop(REF_SETTINGS_KEY, None)
        settings.pop(ORIGIN_SETTINGS_KEY, None)
        if len(input_paths) > 1:
            settings[REF_SETTINGS_KEY] = input_paths[1:]
        settings[ORIGIN_SETTINGS_KEY] = list(input_paths)

        fields = {
            "user_id": user_id,
            "tool_slug": payload.tool_slug,
            "source": source,
            "status": JobStatus.PENDING.value,
            "input_image_url": input_paths[0],
            "style_notes": payload.style_notes,
            "settings": settings,
            "credit_cost": int(pricing.credit_cost),
            "pricing_version": int(pricing.pricing_version),
            "provider": pricing.provider,
            "model": pricing.model,
            "width": pricing.width,
            "height": pricing.height,
            "idempotency_key": payload.idempotency_key,
        }
        if input_expires is not None:
            fields["input_expires_at"] = input_expires.isoformat()

        result = self.db.table("generations").insert(fields).execute()
        return result.data[0]

    def _get(self, generation_id: str) -> dict:
        result = (
            self.db.table("generations")
            .select("*")
            .eq("id", generation_id)
            .limit(1)
            .execute()
        )
        if not result.data:
            raise NotFoundError("Generation not found")
        return result.data[0]

    def _get_by_idempotency(self, user_id: str, key: str) -> dict | None:
        result = (
            self.db.table("generations")
            .select("*")
            .eq("user_id", user_id)
            .eq("idempotency_key", key)
            .limit(1)
            .execute()
        )
        return result.data[0] if result.data else None

    def _list(self, user_id: str, limit: int) -> list[dict]:
        result = (
            self.db.table("generations")
            .select("*")
            .eq("user_id", user_id)
            .is_("deleted_at", "null")
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data or []

    def _set(self, generation_id: str, **fields) -> None:
        fields["updated_at"] = datetime.now(timezone.utc).isoformat()
        self.db.table("generations").update(fields).eq("id", generation_id).execute()

    def _transition(self, row: dict, new_status: str, **fields) -> None:
        current = row["status"]
        allowed = ALLOWED_STATUS_TRANSITIONS.get(current, set())
        if new_status != current and new_status not in allowed:
            # Idempotent no-op for already-terminal same status
            if current == new_status:
                return
            raise ValidationError(f"Invalid status transition {current} → {new_status}")
        fields["status"] = new_status
        self._set(row["id"], **fields)
        row["status"] = new_status
        row.update(fields)

    async def _charge_generation(self, row: dict, credit_cost: int, tool_slug: str) -> None:
        try:
            spend_tx = await self.credits.spend_for_generation(
                user_id=row["user_id"],
                amount=int(credit_cost),
                generation_id=row["id"],
                tool_slug=tool_slug,
                metadata={
                    "pricing_version": row.get("pricing_version"),
                    "provider": row.get("provider"),
                    "model": row.get("model"),
                },
            )
        except InsufficientCreditsError:
            await asyncio.to_thread(
                self._transition,
                row,
                JobStatus.FAILED.value,
                error_message="Insufficient credits",
            )
            raise

        if not spend_tx:
            return

        row["credit_spend_transaction_id"] = spend_tx.id
        await asyncio.to_thread(
            self._set,
            row["id"],
            credit_spend_transaction_id=spend_tx.id,
        )

    async def _provider_image_ref(
        self, path: str, *, target_width: int, target_height: int
    ) -> str | None:
        """Base64 of `path` center-cropped to the tool's aspect ratio, so BFL
        gets an image already framed close to the output instead of having
        to recompose a mismatched aspect ratio (see app/utils/image_transform.py).
        Falls back to the original signed URL if the download/crop fails for
        any reason — never a new failure mode, just loses the framing fix.
        """
        try:
            raw = await asyncio.to_thread(self.storage.download_object, path)
            cropped = fit_to_aspect(raw, target_width, target_height)
            return base64.b64encode(cropped).decode("utf-8")
        except Exception:
            logger.warning(
                "input_crop_failed path=%s falling_back_to_url=true", path[:80]
            )
            return self.storage.access_url(path, for_provider=True)

    async def _process(self, row: dict) -> GenerationOut:
        gen_id = row["id"]
        tool_slug = row["tool_slug"]
        # Caller may have already claimed → processing; keep row in sync.
        if row.get("status") != JobStatus.PROCESSING.value:
            await asyncio.to_thread(
                self._transition,
                row,
                JobStatus.PROCESSING.value,
                started_at=datetime.now(timezone.utc).isoformat(),
            )
        else:
            row["status"] = JobStatus.PROCESSING.value
        logger.info(
            "generation_started id=%s tool=%s user_id=%s credit_cost=%s",
            gen_id,
            tool_slug,
            row["user_id"],
            row.get("credit_cost"),
        )

        try:
            settings = dict(row.get("settings") or {})
            origin_paths = settings.pop(ORIGIN_SETTINGS_KEY, None) or []
            ref_paths = settings.pop(REF_SETTINGS_KEY, None) or []
            if not isinstance(ref_paths, list):
                ref_paths = []
            if not isinstance(origin_paths, list):
                origin_paths = []

            paths = [row["input_image_url"], *[str(p) for p in ref_paths if p]]
            # Together stores origins in ORIGIN; ensure all people are sent.
            if tool_slug == "together":
                for p in origin_paths:
                    s = str(p) if p else ""
                    if s and s not in paths:
                        paths.append(s)
                    if len(paths) >= MAX_INPUT_IMAGES:
                        break
            # Dedup keep order (BFL input slots — unique storage paths)
            seen: set[str] = set()
            unique_paths: list[str] = []
            for p in paths:
                if not p or p in seen:
                    continue
                seen.add(p)
                unique_paths.append(p)
                if len(unique_paths) >= MAX_INPUT_IMAGES:
                    break

            target_width = int(row.get("width") or 1024)
            target_height = int(row.get("height") or 1024)
            provider_urls: list[str] = []
            for path in unique_paths:
                image_ref = await self._provider_image_ref(
                    path, target_width=target_width, target_height=target_height
                )
                if image_ref:
                    provider_urls.append(image_ref)
            if not provider_urls:
                raise AIProviderError("Missing input image")

            # Mirrors BflProvider.edit_image's own duplicate-input rule so cost
            # estimation reflects what BFL is actually billed for as input images.
            billed_input_images = len(provider_urls)
            if billed_input_images <= 1 and self.settings.bfl_duplicate_input_image:
                billed_input_images = 2
            row["_provider_input_count"] = billed_input_images

            output_bytes, provider_request_id = await self.tools.run(
                tool_slug,
                input_image_url=provider_urls[0],
                input_image_urls=provider_urls,
                style_notes=row.get("style_notes"),
                settings=settings,
            )
            # Real BFL cost is now certain — persist it immediately, before the
            # upload step, so the cost record survives even if upload fails.
            _model_slug, model_rates = await asyncio.to_thread(get_active_model, self.db)
            provider_cost = estimate_provider_cost_usd(
                row["width"],
                row["height"],
                model_rates,
                num_input_images=row.get("_provider_input_count", 1),
            )
            cost_fields: dict = {"provider_cost_usd": str(provider_cost)}
            if provider_request_id:
                cost_fields["provider_request_id"] = provider_request_id
            await asyncio.to_thread(self._set, gen_id, **cost_fields)
            row.update(cost_fields)

            uploaded = await asyncio.to_thread(
                self.storage.upload_user_image,
                output_bytes,
                user_id=row["user_id"],
                kind="outputs",
                generation_id=gen_id,
            )
            output_expires = self.storage.retention_expiry(kind="output", is_saved=False)
            fields = {
                "output_image_url": uploaded.path,
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "error_message": None,
            }
            if output_expires is not None:
                fields["output_expires_at"] = output_expires.isoformat()

            await asyncio.to_thread(
                self._transition,
                row,
                JobStatus.COMPLETED.value,
                **fields,
            )
            logger.info("generation_completed id=%s tool=%s", gen_id, tool_slug)
        except Exception as exc:
            await self._fail_and_refund(row, exc)

        refreshed = await asyncio.to_thread(self._get, gen_id)
        return self._to_out(refreshed)

    async def _fail_and_refund(self, row: dict, exc: Exception) -> None:
        gen_id = row["id"]
        tool_slug = row["tool_slug"]
        if isinstance(exc, AIProviderError):
            logger.warning(
                "generation_failed id=%s tool=%s reason=%s",
                gen_id,
                tool_slug,
                str(exc)[:200],
            )
            internal = str(exc)[:500]
        else:
            logger.exception("generation_failed id=%s tool=%s", gen_id, tool_slug)
            internal = "Generation failed"

        # A submitted-but-failed job likely still cost real money — record it so
        # the loss is visible even though the user gets a full credit refund below.
        submitted_id = getattr(exc, "provider_request_id", None)
        if submitted_id and not row.get("provider_request_id"):
            _model_slug, model_rates = await asyncio.to_thread(get_active_model, self.db)
            provider_cost = estimate_provider_cost_usd(
                row["width"],
                row["height"],
                model_rates,
                num_input_images=row.get("_provider_input_count", 1),
            )
            cost_fields = {
                "provider_request_id": submitted_id,
                "provider_cost_usd": str(provider_cost),
            }
            await asyncio.to_thread(self._set, gen_id, **cost_fields)
            row.update(cost_fields)

        refund_tx = await self._refund_if_charged(row)
        fields = {"error_message": internal}
        if refund_tx:
            fields["credit_refund_transaction_id"] = refund_tx.id
            await asyncio.to_thread(
                self._transition, row, JobStatus.REFUNDED.value, **fields
            )
        else:
            await asyncio.to_thread(
                self._transition, row, JobStatus.FAILED.value, **fields
            )

    async def _refund_if_charged(self, row: dict):
        credit_cost = int(row.get("credit_cost") or 0)
        spend_tx_id = row.get("credit_spend_transaction_id")
        if credit_cost <= 0 or not spend_tx_id:
            return None
        if row.get("credit_refund_transaction_id"):
            return None

        return await self.credits.refund_generation(
            user_id=row["user_id"],
            amount=credit_cost,
            generation_id=row["id"],
            tool_slug=row["tool_slug"],
            metadata={"spend_transaction_id": spend_tx_id},
        )

    def _to_out(self, row: dict) -> GenerationOut:
        # Never expose raw provider internals to clients on failed gens
        public = dict(row)
        if public.get("settings") is None:
            public["settings"] = {}
        else:
            # Hide internal storage keys from clients
            settings = dict(public["settings"])
            settings.pop(REF_SETTINGS_KEY, None)
            settings.pop(ORIGIN_SETTINGS_KEY, None)
            public["settings"] = settings
        if public.get("source") is None:
            public["source"] = "upload"
        if public.get("status") in {
            JobStatus.FAILED.value,
            JobStatus.REFUNDED.value,
        }:
            if public.get("credit_refund_transaction_id"):
                public["error_message"] = SAFE_FAIL_MESSAGE
            else:
                public["error_message"] = SAFE_FAIL_NO_REFUND

        out = GenerationOut.model_validate(public)

        input_url = out.input_image_url
        output_url = out.output_image_url
        if not row.get("input_purged_at"):
            try:
                signed_in = self.storage.access_url(out.input_image_url)
                if signed_in:
                    input_url = signed_in
            except Exception:
                logger.exception(
                    "sign_input_failed generation_id=%s", out.id
                )
        if not row.get("output_purged_at"):
            try:
                signed_out = self.storage.access_url(out.output_image_url)
                if signed_out:
                    output_url = signed_out
            except Exception:
                logger.exception(
                    "sign_output_failed generation_id=%s", out.id
                )

        return out.model_copy(
            update={
                "input_image_url": input_url,
                "output_image_url": output_url,
            }
        )
