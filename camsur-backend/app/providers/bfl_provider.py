"""
Black Forest Labs (FLUX) provider.

Docs: https://docs.bfl.ml/quick_start/introduction
Edit: POST /v1/{model} with input_image → poll polling_url → download sample
Auth: x-key header
"""

from __future__ import annotations

import asyncio
import base64
from urllib.parse import urlparse

import httpx

from app.config import Settings
from app.core.exceptions import AIProviderError
from app.core.logging import get_logger
from app.providers.base import BaseProvider, ProviderResult

DEFAULT_MODEL = "flux-2-pro"

# Statuses that mean "still working" — anything else BFL reports is terminal
# (a fail-safe allow-list, not a fail-open one: an unrecognized future status
# string is treated as a failure to report immediately, not silently polled
# through to the timeout).
_IN_PROGRESS_STATUSES = {"Pending", "Processing", "Request Accepted", "Task Queued"}

logger = get_logger(__name__)


class BflProvider(BaseProvider):
    name = "bfl"

    def __init__(self, settings: Settings, *, model_override: str | None = None):
        super().__init__(settings)
        self.api_key = settings.bfl_api_key
        self.api_base = settings.bfl_api_base.rstrip("/")
        # model_override lets callers use the admin-configured active model
        # (ai_provider_settings, read by ToolService) without mutating the
        # shared, process-wide Settings singleton.
        self.model = model_override or settings.bfl_model or DEFAULT_MODEL
        self.poll_interval = settings.bfl_poll_interval_sec
        self.poll_max_attempts = settings.bfl_poll_max_attempts
        self.http_timeout = settings.bfl_http_timeout_sec
        self.max_download_bytes = settings.bfl_max_download_bytes
        self.duplicate_input = settings.bfl_duplicate_input_image
        self.allowed_hosts = settings.bfl_result_host_allowlist
        self.max_error_len = settings.max_provider_error_log_length

    async def edit_image(
        self,
        prompt: str,
        *,
        input_image_url: str | None = None,
        input_image_bytes: bytes | None = None,
        input_image_urls: list[str] | None = None,
        width: int = 1024,
        height: int = 1024,
        guidance: float | None = None,
        steps: int | None = None,
        seed: int | None = None,
        safety_tolerance: int | None = None,
        prompt_upsampling: bool | None = None,
        output_format: str | None = None,
    ) -> ProviderResult:
        if not self.api_key:
            raise AIProviderError("BFL_API_KEY is not configured")

        urls = [u for u in (input_image_urls or []) if u]
        if input_image_url and input_image_url not in urls:
            urls = [input_image_url] + urls
        if not urls and input_image_bytes:
            urls = []
        if not urls and not input_image_bytes:
            raise AIProviderError("BFL edit needs input_image_url or input_image_bytes")

        # Cap at 5 unique refs (BFL pro supports up to 8; Camsur product lock is 5).
        seen: set[str] = set()
        unique_urls: list[str] = []
        for u in urls:
            if u in seen:
                continue
            seen.add(u)
            unique_urls.append(u)
            if len(unique_urls) >= 5:
                break

        primary = unique_urls[0] if unique_urls else (
            base64.b64encode(input_image_bytes).decode("utf-8") if input_image_bytes else None
        )
        if not primary:
            raise AIProviderError("BFL edit needs input_image_url or input_image_bytes")

        g = float(guidance if guidance is not None else self.settings.bfl_guidance)
        g = max(1.5, min(10.0, g))
        s = int(steps if steps is not None else self.settings.bfl_steps)
        s = max(1, min(50, s))
        st = int(safety_tolerance) if safety_tolerance is not None else 2
        st = max(0, min(5, st))
        upsampling = bool(prompt_upsampling) if prompt_upsampling is not None else False

        payload: dict = {
            "prompt": prompt,
            "input_image": primary,
            "width": width,
            "height": height,
            "output_format": output_format or "jpeg",
            "disable_pup": not upsampling,
            "guidance": g,
            "steps": s,
            "safety_tolerance": st,
        }
        if seed is not None:
            payload["seed"] = int(seed)

        # Multi-ref identity: distinct photos as input_image_2..5
        for idx, url in enumerate(unique_urls[1:5], start=2):
            payload[f"input_image_{idx}"] = url

        # Legacy single-photo identity lock: duplicate primary as image 2 when only one input.
        if len(unique_urls) <= 1 and self.duplicate_input:
            payload["input_image_2"] = primary

        submit_url = f"{self.api_base}/v1/{self.model}"
        logger.info(
            "bfl_job_submitting model=%s refs=%s guidance=%s steps=%s "
            "width=%s height=%s image_input=%s",
            self.model,
            len(unique_urls) or 1,
            g,
            s,
            width,
            height,
            "url" if primary.startswith("http") else "base64",
        )
        return await self._submit_and_fetch(payload, submit_url)

    async def generate_image(
        self,
        prompt: str,
        *,
        width: int = 1024,
        height: int = 1024,
        guidance: float = 3.0,
        steps: int = 40,
    ) -> ProviderResult:
        """Pure text-to-image — no input_image at all. Used only for
        generating a tool's catalog/thumbnail image, never for editing a
        real user photo. Callers should pass a cheap model_override (see
        __init__) since catalog images don't need premium quality.
        """
        if not self.api_key:
            raise AIProviderError("BFL_API_KEY is not configured")

        payload: dict = {
            "prompt": prompt,
            "width": width,
            "height": height,
            "output_format": "jpeg",
            "disable_pup": True,
            "guidance": max(1.5, min(10.0, float(guidance))),
            "steps": max(1, min(50, int(steps))),
        }
        submit_url = f"{self.api_base}/v1/{self.model}"
        logger.info(
            "bfl_generate_job_submitting model=%s width=%s height=%s",
            self.model,
            width,
            height,
        )
        return await self._submit_and_fetch(payload, submit_url)

    async def _submit_and_fetch(self, payload: dict, submit_url: str) -> ProviderResult:
        headers = {
            "accept": "application/json",
            "x-key": self.api_key,
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=self.http_timeout) as client:
            try:
                submit = await client.post(submit_url, headers=headers, json=payload)
            except httpx.HTTPError as exc:
                raise AIProviderError("BFL request failed") from exc

            if submit.status_code == 402:
                raise AIProviderError("BFL: insufficient credits")
            if submit.status_code == 429:
                raise AIProviderError("BFL: rate limited — try again shortly")
            if submit.status_code >= 400:
                logger.warning(
                    "bfl_submit_error status=%s body=%s",
                    submit.status_code,
                    _truncate(submit.text, self.max_error_len),
                )
                raise AIProviderError(f"BFL submit failed ({submit.status_code})")

            data = submit.json()
            provider_request_id = str(data.get("id") or data.get("task_id") or "") or None
            polling_url = data.get("polling_url")

            # From here on, BFL has accepted the job — any failure below likely still
            # incurred real provider cost. Attach the request id to whatever gets
            # raised so callers can record that cost even on failure.
            try:
                if not polling_url:
                    raise AIProviderError("BFL response missing polling_url")

                logger.info("bfl_job_submitted request_id=%s", provider_request_id)
                sample_url = await self._poll_until_ready(client, headers, polling_url)
                self._assert_trusted_result_url(sample_url)

                try:
                    image_resp = await client.get(sample_url)
                    image_resp.raise_for_status()
                except httpx.HTTPError as exc:
                    raise AIProviderError("BFL download failed") from exc

                content = image_resp.content
                if len(content) > self.max_download_bytes:
                    raise AIProviderError("BFL output exceeds size limit")
                if not content:
                    raise AIProviderError("BFL returned empty image")
            except Exception as exc:
                if getattr(exc, "provider_request_id", None) is None:
                    try:
                        exc.provider_request_id = provider_request_id
                    except AttributeError:
                        pass
                raise

            return ProviderResult(image_bytes=content, request_id=provider_request_id)

    # A dropped connection on one poll GET must not fail a job that BFL has
    # already accepted (and already been billed for) — tolerate a handful of
    # consecutive transient network errors before giving up, the same way
    # the Flutter client's own polling loop does.
    _MAX_CONSECUTIVE_POLL_ERRORS = 5

    async def _poll_until_ready(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        polling_url: str,
    ) -> str:
        consecutive_errors = 0
        for attempt in range(self.poll_max_attempts):
            if attempt > 0:
                await asyncio.sleep(self.poll_interval)
            try:
                result = await client.get(polling_url, headers=headers)
                result.raise_for_status()
                body = result.json()
                consecutive_errors = 0
            except httpx.HTTPError as exc:
                consecutive_errors += 1
                if consecutive_errors >= self._MAX_CONSECUTIVE_POLL_ERRORS:
                    raise AIProviderError("BFL poll failed") from exc
                logger.warning(
                    "bfl_poll_transient_error attempt=%s consecutive_errors=%s error=%s",
                    attempt,
                    consecutive_errors,
                    str(exc)[:200],
                )
                continue

            status = body.get("status")
            if status == "Ready":
                sample = (body.get("result") or {}).get("sample")
                if not sample:
                    raise AIProviderError("BFL Ready but no result.sample URL")
                return sample
            if status not in _IN_PROGRESS_STATUSES:
                # Anything else — Error, Failed, Content Moderated, Request
                # Moderated, or any future status we don't know about yet —
                # is terminal. BFL will never move it to Ready from here, so
                # failing fast beats silently polling for the full timeout
                # (this previously took 5 minutes to surface a moderation
                # block as a generic "timed out" error).
                logger.warning(
                    "bfl_generation_failed status=%s detail=%s",
                    status,
                    _truncate(str(body), self.max_error_len),
                )
                if status and "moderat" in status.lower():
                    raise AIProviderError(
                        "BFL: content flagged by moderation (try a less strict "
                        "safety_tolerance or a different photo/prompt)"
                    )
                raise AIProviderError(f"BFL generation failed: {status or 'unknown status'}")

        raise AIProviderError("BFL timed out waiting for result")

    def _assert_trusted_result_url(self, url: str) -> None:
        host = urlparse(url).netloc.lower()
        if not host:
            raise AIProviderError("BFL returned invalid result URL")
        # Allow exact host or subdomain of configured allowlist entries.
        for allowed in self.allowed_hosts:
            if host == allowed or host.endswith("." + allowed):
                return
        logger.warning("bfl_untrusted_result_host host=%s", host)
        raise AIProviderError("BFL returned untrusted result host")


def _truncate(value: str, limit: int) -> str:
    text = value or ""
    if len(text) <= limit:
        return text
    return text[:limit] + "…"
