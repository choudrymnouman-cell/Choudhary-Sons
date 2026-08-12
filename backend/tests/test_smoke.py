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
    assert payload["version"] == "0.6.0"


def test_root_reports_current_version():
    response = client.get("/")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "running"
    assert payload["version"] == "0.6.0"


def test_protected_endpoint_requires_authentication():
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
