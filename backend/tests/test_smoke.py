import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./test_choudhary_sons.db")
os.environ.setdefault("SECRET_KEY", "test-secret-key")

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["version"] == "0.9.0"


def test_root_reports_current_version():
    response = client.get("/")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "running"
    assert payload["version"] == "0.9.0"
    assert payload["supabase_storage"] is False


def test_protected_endpoint_requires_authentication():
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401


def test_cors_preflight_for_local_web():
    response = client.options(
        "/api/v1/auth/login",
        headers={
            "Origin": "http://localhost:8080",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == "http://localhost:8080"
