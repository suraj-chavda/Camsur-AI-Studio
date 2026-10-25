"""Unit tests for pure helpers and response envelopes (no live Supabase)."""

from __future__ import annotations

from app.config import Settings
from app.core.response import fail, ok
from app.services.tool_service import _public_settings
from app.utils.storage_url import extract_object_ref, is_allowed_input_image


def _settings() -> Settings:
    return Settings(
        supabase_url="https://example.supabase.co",
        supabase_media_bucket="camsur-media",
        supabase_assets_bucket="camsur-backend-images",
        supabase_bucket="",
        debug=True,
        environment="development",
    )


def test_ok_fail_envelope():
    assert ok(data={"a": 1}, message="hi") == {
        "success": True,
        "message": "hi",
        "data": {"a": 1},
    }
    assert fail(message="nope") == {
        "success": False,
        "message": "nope",
        "data": None,
    }


def test_public_settings_strip_prompts():
    settings = [
        {
            "key": "style",
            "label": "Style",
            "prompt": "secret backend prompt",
            "options": [
                {"value": "a", "label": "A", "prompt": "option secret"},
            ],
        }
    ]
    public = _public_settings(settings)
    assert "prompt" not in public[0]
    assert public[0]["options"][0]["value"] == "a"
    assert "prompt" not in public[0]["options"][0]


def test_storage_allowlist_accepts_media_upload_path():
    settings = _settings()
    assert is_allowed_input_image("uploads/abc.jpg", settings)
    assert is_allowed_input_image(
        "users/11111111-1111-1111-1111-111111111111/uploads/abc.jpg",
        settings,
    )
    assert extract_object_ref("uploads/abc.jpg", settings) == ("camsur-media", "uploads/abc.jpg")


def test_storage_allowlist_rejects_external_and_assets():
    settings = _settings()
    assert not is_allowed_input_image("https://evil.example/x.jpg", settings)
    assert not is_allowed_input_image("http://127.0.0.1:9/secret", settings)
    assert not is_allowed_input_image("assets/tools/x.jpg", settings)

    signed = (
        "https://example.supabase.co/storage/v1/object/sign/"
        "camsur-media/uploads/abc.jpg?token=abc"
    )
    assert is_allowed_input_image(signed, settings)
    assert extract_object_ref(signed, settings) == ("camsur-media", "uploads/abc.jpg")
