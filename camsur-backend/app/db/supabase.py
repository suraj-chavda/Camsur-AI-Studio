from functools import lru_cache

from supabase import Client, create_client

from app.config import get_settings


@lru_cache
def get_supabase() -> Client:
    """Shared Secret-key client for DB / Storage / admin Auth.

    Never call sign_in on this client — that would replace the secret key
    with a user JWT and break RLS bypass.
    """
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_key)


def new_auth_client() -> Client:
    """Fresh client used only to obtain access/refresh tokens."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_key)
