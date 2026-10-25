import asyncio
import json
from typing import Annotated

from fastapi import APIRouter, File, Form, Header, Query, UploadFile

from app.core.enums import ImageSource
from app.core.exceptions import ValidationError
from app.core.logging import get_logger
from app.core.response import ok
from app.dependencies import CurrentUserDep, GenerationServiceDep, StorageServiceDep
from app.schemas.generation_schema import (
    MAX_INPUT_IMAGES,
    GenerationCreate,
    GenerationOut,
)
from app.services.generation_service import GenerationService
from app.utils.image_util import read_upload

router = APIRouter(prefix="/generations", tags=["generations"])
logger = get_logger(__name__)


def _dump(result: GenerationOut) -> dict:
    return result.model_dump(mode="json")


def _schedule_process(service: GenerationService, generation_id: str) -> None:
    """Run processing immediately on the event loop.

    FastAPI BackgroundTasks only run *after* the response is sent. If the
    client drops (common with multi-photo uploads) or encoding fails, the job
    stays pending forever. create_task starts work as soon as we accept it.
    """

    async def _run() -> None:
        try:
            await service.process_generation(generation_id)
        except Exception:
            logger.exception("background_process_failed id=%s", generation_id)

    asyncio.create_task(_run())


@router.post("")
async def create_generation(
    current_user: CurrentUserDep,
    service: GenerationServiceDep,
    payload: GenerationCreate,
    x_async: Annotated[str | None, Header(alias="X-Async")] = None,
):
    async_mode = _wants_async(x_async)
    result = await service.create(current_user.id, payload, async_mode=async_mode)
    if async_mode and result.status == "pending":
        _schedule_process(service, result.id)
        return ok(data=_dump(result), message="Generation accepted")
    return ok(data=_dump(result), message="Generation finished")


@router.post("/from-photo")
async def create_from_photo(
    current_user: CurrentUserDep,
    service: GenerationServiceDep,
    storage: StorageServiceDep,
    tool_slug: str = Form(...),
    source: ImageSource = Form(ImageSource.UPLOAD),
    style_notes: str | None = Form(None),
    settings: str | None = Form(None),
    idempotency_key: str | None = Form(None),
    # Prefer `photos` (1–5). Keep legacy single `photo` for older clients.
    photos: Annotated[list[UploadFile] | None, File()] = None,
    photo: UploadFile | None = File(None),
    x_async: Annotated[str | None, Header(alias="X-Async")] = None,
):
    """Upload 1–5 photos (tool-enforced) and run a DB-configured tool. Requires auth."""
    await service.ensure_can_create(current_user.id, tool_slug)

    uploads = _collect_uploads(photos=photos, photo=photo)
    if not uploads:
        raise ValidationError("At least one photo is required")
    if len(uploads) > MAX_INPUT_IMAGES:
        raise ValidationError(f"At most {MAX_INPUT_IMAGES} photos are allowed")

    paths: list[str] = []
    for file in uploads:
        image_bytes = await read_upload(file)
        uploaded = await asyncio.to_thread(
            storage.upload_user_image,
            image_bytes,
            user_id=current_user.id,
            kind="uploads",
        )
        paths.append(uploaded.path)

    payload = GenerationCreate(
        tool_slug=tool_slug,
        source=source,
        input_image_urls=paths,
        style_notes=style_notes,
        settings=_parse_settings(settings),
        idempotency_key=idempotency_key,
    )
    async_mode = _wants_async(x_async)
    result = await service.create(current_user.id, payload, async_mode=async_mode)
    if async_mode and result.status == "pending":
        _schedule_process(service, result.id)
        return ok(data=_dump(result), message="Generation accepted")
    return ok(data=_dump(result), message="Generation finished")


@router.get("/mine")
async def list_my_generations(
    current_user: CurrentUserDep,
    service: GenerationServiceDep,
    limit: int = Query(default=20, ge=1, le=50),
):
    results = await service.list_by_user(current_user.id, limit=limit)
    return ok(data=[_dump(r) for r in results])


@router.get("/{generation_id}")
async def get_generation(
    generation_id: str,
    current_user: CurrentUserDep,
    service: GenerationServiceDep,
):
    result = await service.get_by_id(generation_id, current_user.id)
    # Recover jobs that were accepted but never processed (client drop / reload).
    if result.status == "pending":
        _schedule_process(service, result.id)
    return ok(data=_dump(result))


@router.delete("/{generation_id}")
async def delete_generation(
    generation_id: str,
    current_user: CurrentUserDep,
    service: GenerationServiceDep,
):
    """Delete generation media. Does NOT refund credits."""
    await service.soft_delete(generation_id, current_user.id)
    return ok(message="Deleted")


def _collect_uploads(
    *,
    photos: list[UploadFile] | None,
    photo: UploadFile | None,
) -> list[UploadFile]:
    files: list[UploadFile] = []
    if photos:
        files.extend([f for f in photos if f is not None and getattr(f, "filename", None)])
    if photo is not None and getattr(photo, "filename", None):
        files.append(photo)
    return files


def _wants_async(value: str | None) -> bool:
    if not value:
        return False
    return value.strip().lower() in {"1", "true", "yes", "async"}


def _parse_settings(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValidationError("settings must be valid JSON object") from exc
    if not isinstance(value, dict):
        raise ValidationError("settings must be a JSON object")
    return value
