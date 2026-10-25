import asyncio

from supabase import Client

from app.core.exceptions import NotFoundError, UnauthorizedError, ValidationError
from app.db.supabase import new_auth_client
from app.schemas.user_schema import (
    AuthOut,
    LoginRequest,
    RegisterRequest,
    SocialLoginRequest,
    UserOut,
)
from app.services.credit_service import CreditService


class AuthService:
    """Email + password auth, plus Google/Apple via Supabase ID-token sign-in."""

    def __init__(self, db: Client):
        # Service client — Secret key only (RLS bypass). Never sign_in here.
        self.db = db
        self.credits = CreditService(db)

    async def register(self, payload: RegisterRequest) -> AuthOut:
        return await asyncio.to_thread(self._register, payload)

    async def login(self, payload: LoginRequest) -> AuthOut:
        return await asyncio.to_thread(self._login, payload)

    async def social_login(self, payload: SocialLoginRequest) -> AuthOut:
        return await asyncio.to_thread(self._social_login, payload)

    async def get_user_from_token(self, access_token: str) -> UserOut:
        return await asyncio.to_thread(self._get_user_from_token, access_token)

    async def refresh(self, refresh_token: str) -> AuthOut:
        return await asyncio.to_thread(self._refresh, refresh_token)

    def _register(self, payload: RegisterRequest) -> AuthOut:
        # Admin create + email_confirm so no confirmation email is required.
        try:
            created = self.db.auth.admin.create_user(
                {
                    "email": str(payload.email),
                    "password": payload.password,
                    "email_confirm": True,
                    "user_metadata": {
                        "display_name": payload.display_name,
                        "device_id": payload.device_id,
                    },
                }
            )
        except Exception as exc:
            raise ValidationError(_auth_message(exc, "Registration failed")) from exc

        if not created.user:
            raise ValidationError("Registration failed")

        self._upsert_profile(
            user_id=created.user.id,
            email=str(payload.email),
            display_name=payload.display_name,
            device_id=payload.device_id,
        )
        return self._login(
            LoginRequest(email=payload.email, password=payload.password)
        )

    def _login(self, payload: LoginRequest) -> AuthOut:
        # Separate client so user session does not stick on the service client
        auth_client = new_auth_client()
        try:
            result = auth_client.auth.sign_in_with_password(
                {"email": str(payload.email), "password": payload.password}
            )
        except Exception as exc:
            raise UnauthorizedError(
                _auth_message(exc, "Invalid email or password")
            ) from exc

        if not result.session or not result.user:
            raise UnauthorizedError("Invalid email or password")

        self._upsert_profile(
            user_id=result.user.id,
            email=result.user.email or str(payload.email),
            display_name=(result.user.user_metadata or {}).get("display_name"),
            device_id=(result.user.user_metadata or {}).get("device_id"),
        )
        user = self._get_profile(result.user.id)
        return AuthOut(
            access_token=result.session.access_token,
            refresh_token=result.session.refresh_token,
            user=user,
        )

    def _social_login(self, payload: SocialLoginRequest) -> AuthOut:
        # Mobile app already ran native Google/Apple sign-in and holds an ID
        # token; Supabase verifies it against the provider config set up in
        # the dashboard and creates/logs in the matching auth.users row.
        credentials: dict = {"provider": payload.provider, "token": payload.id_token}
        if payload.access_token:
            credentials["access_token"] = payload.access_token
        if payload.nonce:
            credentials["nonce"] = payload.nonce

        auth_client = new_auth_client()
        try:
            result = auth_client.auth.sign_in_with_id_token(credentials)
        except Exception as exc:
            raise UnauthorizedError(_auth_message(exc, "Social sign-in failed")) from exc

        if not result.session or not result.user:
            raise UnauthorizedError("Social sign-in failed")

        metadata = result.user.user_metadata or {}
        # Google/Apple id tokens surface the name under full_name/name, not
        # our own display_name key (only ever set by our /auth/register).
        display_name = (
            metadata.get("display_name")
            or metadata.get("full_name")
            or metadata.get("name")
        )
        self._upsert_profile(
            user_id=result.user.id,
            email=result.user.email or "",
            display_name=display_name,
            device_id=payload.device_id,
        )
        user = self._get_profile(result.user.id)
        return AuthOut(
            access_token=result.session.access_token,
            refresh_token=result.session.refresh_token,
            user=user,
        )

    def _get_user_from_token(self, access_token: str) -> UserOut:
        try:
            result = self.db.auth.get_user(access_token)
        except Exception as exc:
            raise UnauthorizedError(
                _auth_message(exc, "Invalid or expired token")
            ) from exc

        if not result or not result.user:
            raise UnauthorizedError("Invalid or expired token")

        return self._get_profile(result.user.id)

    def _refresh(self, refresh_token: str) -> AuthOut:
        token = (refresh_token or "").strip()
        if not token:
            raise UnauthorizedError("Missing refresh token")

        auth_client = new_auth_client()
        try:
            result = auth_client.auth.refresh_session(token)
        except Exception as exc:
            raise UnauthorizedError(
                _auth_message(exc, "Session expired. Please sign in again.")
            ) from exc

        if not result.session or not result.user:
            raise UnauthorizedError("Session expired. Please sign in again.")

        user = self._get_profile(result.user.id)
        return AuthOut(
            access_token=result.session.access_token,
            refresh_token=result.session.refresh_token,
            user=user,
        )

    def _upsert_profile(
        self,
        user_id: str,
        email: str,
        display_name: str | None,
        device_id: str | None,
    ) -> None:
        existing = (
            self.db.table("users").select("id").eq("id", user_id).limit(1).execute()
        )
        if existing.data:
            self.credits.ensure_account(user_id)
            return

        self.db.table("users").insert(
            {
                "id": user_id,
                "email": email,
                "display_name": display_name or _derive_display_name(email),
                "device_id": device_id,
            }
        ).execute()
        self.credits.ensure_account(user_id)

    def _get_profile(self, user_id: str) -> UserOut:
        result = self.db.table("users").select("*").eq("id", user_id).limit(1).execute()
        if not result.data:
            raise NotFoundError("User profile not found")
        return UserOut.model_validate(result.data[0])


def _derive_display_name(email: str) -> str:
    """Fallback display name from the email local-part (no name from client/provider)."""
    local = (email or "").split("@", 1)[0]
    words = [w for w in local.replace(".", " ").replace("_", " ").replace("-", " ").split() if w]
    return " ".join(w.capitalize() for w in words) or "Camsur User"


def _auth_message(exc: Exception, fallback: str) -> str:
    raw = getattr(exc, "message", None) or str(exc)
    message = "".join(ch for ch in str(raw) if ch.isprintable()).strip()
    if not message or len(message) > 180 or "\\x" in message:
        return fallback
    # Keep client-facing auth errors short and readable.
    lower = message.lower()
    if "expired" in lower or "invalid jwt" in lower or "invalid token" in lower:
        return "Invalid or expired token"
    if "invalid login" in lower or "invalid credentials" in lower:
        return "Invalid email or password"
    return message
