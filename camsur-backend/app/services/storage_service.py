from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from supabase import Client

from app.config import Settings
from app.core.exceptions import ValidationError
from app.utils.image_util import detect_image_format, make_user_object_name
from app.utils.storage_url import extract_object_ref, is_allowed_input_image


@dataclass(frozen=True)
class UploadedImage:
    path: str
    url: str
    bucket: str


class StorageService:
    """Upload private user media and issue short-lived signed URLs."""

    def __init__(self, db: Client, settings: Settings):
        self.settings = settings
        self.client = db
        self.media_bucket = settings.media_bucket
        self.assets_bucket = settings.assets_bucket

    def upload_user_image(
        self,
        data: bytes,
        *,
        user_id: str,
        kind: str,
        generation_id: str | None = None,
    ) -> UploadedImage:
        image_format = detect_image_format(data)
        object_name = make_user_object_name(
            user_id,
            kind,
            generation_id=generation_id,
            image_format=image_format,
        )
        return self._upload_bytes(object_name, data, image_format)

    def _upload_bytes(self, object_name: str, data: bytes, image_format: str) -> UploadedImage:
        content_type = {
            "JPEG": "image/jpeg",
            "PNG": "image/png",
            "WEBP": "image/webp",
        }.get(image_format.upper(), "image/jpeg")

        self.client.storage.from_(self.media_bucket).upload(
            path=object_name,
            file=data,
            file_options={"content-type": content_type, "upsert": "false"},
        )
        return UploadedImage(
            path=object_name,
            url=self.sign_media_path(object_name),
            bucket=self.media_bucket,
        )

    def normalize_input_ref(self, value: str, *, user_id: str | None = None) -> str:
        if not is_allowed_input_image(value, self.settings):
            raise ValidationError(
                "input_image_url must be an image previously uploaded to Camsur storage"
            )
        ref = extract_object_ref(value, self.settings)
        assert ref is not None
        _bucket, path = ref
        if user_id and path.startswith("users/") and f"users/{user_id}/" not in path:
            raise ValidationError("Not allowed to use another user's media")
        return path

    def access_url(
        self,
        value: str | None,
        *,
        expires_in: int | None = None,
        for_provider: bool = False,
    ) -> str | None:
        if not value:
            return None

        ref = extract_object_ref(value, self.settings)
        if not ref:
            return value

        bucket, path = ref
        ttl = expires_in
        if ttl is None:
            ttl = (
                self.settings.signed_url_bfl_expires_sec
                if for_provider
                else self.settings.signed_url_expires_sec
            )

        if bucket == self.assets_bucket and bucket != self.media_bucket:
            return self.client.storage.from_(bucket).get_public_url(path)
        if path.startswith("assets/"):
            return self.client.storage.from_(bucket).get_public_url(path)
        return self._sign(bucket, path, ttl)

    def sign_media_path(self, path: str, *, expires_in: int | None = None) -> str:
        ttl = expires_in or self.settings.signed_url_expires_sec
        return self._sign(self.media_bucket, path, ttl)

    def delete_object(self, path: str) -> None:
        if not path or ".." in path.split("/"):
            raise ValidationError("Invalid storage path")
        self.client.storage.from_(self.media_bucket).remove([path])

    def download_object(self, path: str) -> bytes:
        if not path or ".." in path.split("/"):
            raise ValidationError("Invalid storage path")
        return self.client.storage.from_(self.media_bucket).download(path)

    def retention_expiry(self, *, kind: str, is_saved: bool = False) -> datetime | None:
        days = 0
        if kind == "upload":
            days = self.settings.upload_retention_days
        elif kind == "output":
            days = (
                self.settings.saved_output_retention_days
                if is_saved
                else self.settings.output_retention_days
            )
        if days <= 0:
            return None
        return datetime.now(timezone.utc) + timedelta(days=days)

    def _sign(self, bucket: str, path: str, expires_in: int) -> str:
        result = self.client.storage.from_(bucket).create_signed_url(path, expires_in)
        url = result.get("signedURL") or result.get("signedUrl")
        if not url:
            raise RuntimeError(f"Failed to create signed URL for {bucket}/{path}")
        # SDK sometimes returns a relative path — clients need an absolute URL.
        if url.startswith("/"):
            base = self.settings.supabase_url.rstrip("/")
            url = f"{base}{url}"
        return url
