import asyncio

from fastapi import APIRouter, File, UploadFile

from app.core.exceptions import InsufficientCreditsError
from app.core.response import ok
from app.dependencies import CreditServiceDep, CurrentUserDep, StorageServiceDep
from app.utils.image_util import read_upload

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/image")
async def upload_image(
    current_user: CurrentUserDep,
    credits: CreditServiceDep,
    storage: StorageServiceDep,
    photo: UploadFile = File(...),
):
    """Upload an image to private media storage. Requires auth + credits. No storage fee."""
    balance = await credits.get_balance(current_user.id)
    if balance.balance <= 0:
        raise InsufficientCreditsError("Add credits before uploading images")

    data = await read_upload(photo)
    uploaded = await asyncio.to_thread(
        storage.upload_user_image,
        data,
        user_id=current_user.id,
        kind="uploads",
    )
    return ok(
        data={"path": uploaded.path, "url": uploaded.url},
        message="Uploaded",
    )
