from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import create_app


def setup_function():
    get_settings.cache_clear()


def teardown_function():
    get_settings.cache_clear()


def test_validation_error_uses_envelope(monkeypatch):
    monkeypatch.setenv("DEBUG", "true")
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("RATE_LIMIT_ENABLED", "false")
    get_settings.cache_clear()
    client = TestClient(create_app())

    response = client.post(
        "/api/v1/auth/register",
        json={"email": "not-an-email", "password": "short"},
    )
    assert response.status_code == 422
    body = response.json()
    assert body["success"] is False
    assert "message" in body
    assert body["data"] is not None
    assert "errors" in body["data"]


def test_missing_auth_uses_envelope(monkeypatch):
    monkeypatch.setenv("DEBUG", "true")
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("RATE_LIMIT_ENABLED", "false")
    get_settings.cache_clear()
    client = TestClient(create_app())

    response = client.get("/api/v1/credits/balance")
    assert response.status_code == 401
    body = response.json()
    assert body == {
        "success": False,
        "message": "Missing Bearer token",
        "data": None,
    }
