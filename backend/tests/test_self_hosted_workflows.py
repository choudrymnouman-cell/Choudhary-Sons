from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.main import app
from app.models.core import User, UserRole

API = "/api/v1"
TRADE = f"{API}/commercial"
HIRING = f"{API}/recruitment"
PASSWORD = "  workflow-test-password  "


def login(client, email):
    response = client.post(f"{API}/auth/login", data={"username": email, "password": PASSWORD})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def create(client, path, headers, values, status=201):
    response = client.post(path, headers=headers, json=values)
    assert response.status_code == status, response.text
    return response.json()


@pytest.fixture
def session(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "upload_dir", str(tmp_path))
    suffix = uuid4().hex[:12]
    with SessionLocal() as db:
        db.add(User(
            email=f"owner-{suffix}@example.com", full_name="Workflow owner",
            password_hash=hash_password(PASSWORD), role=UserRole.OWNER,
        ))
        db.commit()
    with TestClient(app) as client:
        yield client, login(client, f"owner-{suffix}@example.com"), suffix


def test_stock_and_billing_workflows(session):
    client, owner, tag = session
    project = create(client, f"{API}/projects", owner, {"code": f"P-{tag}", "name": "Project"}, 200)
    material = create(client, f"{TRADE}/materials", owner, {
        "sku": f"M-{tag}", "name": "Material", "quantity_on_hand": 10, "average_cost": 20,
    }, 200)
    supplier = create(client, f"{TRADE}/suppliers", owner, {"name": "Supplier"}, 200)
    other = create(client, f"{TRADE}/suppliers", owner, {"name": "Other"}, 200)
    client_record = create(client, f"{TRADE}/clients", owner, {"name": "Billing client"})
    order = create(client, f"{TRADE}/purchase-orders", owner, {
        "po_number": f"PO-{tag}", "supplier_id": supplier["id"], "project_id": project["id"],
        "order_date": "2026-11-01", "total_amount": 100,
    }, 200)

    create(client, f"{TRADE}/deliveries", owner, {
        "purchase_order_id": order["id"], "material_id": material["id"],
        "quantity": 10, "unit_cost": 40, "challan_number": "CH-1",
    })
    inventory = client.get(f"{TRADE}/materials", headers=owner).json()
    balance = next(row for row in inventory if row["id"] == material["id"])
    assert balance["quantity_on_hand"] == 20
    assert balance["average_cost"] == 30
    assert client.get(f"{TRADE}/deliveries", headers=owner).json()[0]["purchase_orders"]["po_number"] == order["po_number"]

    issue = {"material_id": material["id"], "movement_type": "issued", "project_id": project["id"]}
    create(client, f"{TRADE}/stock-movements", owner, {**issue, "quantity": 25}, 409)
    create(client, f"{TRADE}/stock-movements", owner, {**issue, "quantity": 5})
    movements = client.get(f"{TRADE}/stock-movements", headers=owner).json()
    assert [row["movement_type"] for row in movements if row["material_id"] == material["id"]] == ["issued", "received"]

    payment = {"purchase_order_id": order["id"], "amount": "25.00"}
    create(client, f"{TRADE}/supplier-payments", owner, {**payment, "supplier_id": other["id"]}, 422)
    create(client, f"{TRADE}/supplier-payments", owner, {**payment, "supplier_id": supplier["id"]})
    assert client.get(f"{TRADE}/supplier-payments", headers=owner).json()[0]["suppliers"]["name"] == "Supplier"

    invoice = create(client, f"{TRADE}/invoices", owner, {
        "invoice_number": f"INV-{tag}", "project_id": project["id"], "client_id": client_record["id"],
        "invoice_date": "2026-11-01", "amount": 100, "tax_amount": 10,
    }, 200)
    path = f"{TRADE}/invoices/{invoice['id']}/receipts"
    create(client, path, owner, {"amount": "40.50"})
    create(client, path, owner, {"amount": "70.00"}, 409)
    create(client, path, owner, {"amount": "69.50"})
    rows = client.get(f"{TRADE}/receivables", headers=owner).json()
    current = next(row for row in rows if row["id"] == invoice["id"])
    assert (current["paid_amount"], current["status"], current["clients"]["name"]) == (110, "paid", "Billing client")
    assert client.get(f"{TRADE}/receivables").status_code == 401


def test_applicant_and_hr_workflow(session):
    client, hr, tag = session
    email = f"applicant-{tag}@example.com"
    another_email = f"other-{tag}@example.com"
    for address in (email, another_email):
        create(client, f"{HIRING}/signup", {}, {"full_name": "Applicant", "email": address, "password": PASSWORD})
    applicant = login(client, email.upper())
    other = login(client, another_email)
    assert client.get(f"{API}/projects", headers=applicant).status_code == 403
    assert client.get(f"{HIRING}/hr/applications", headers=applicant).status_code == 403
    assert client.put(f"{HIRING}/preferences", headers=applicant, json={
        "preferred_department": "Operations", "min_expected_salary": 40000, "receive_job_alerts": True,
    }).status_code == 200
    job = create(client, f"{API}/jobs", hr, {
        "title": "Site Engineer", "department": "Operations", "description": "Site coverage", "salary_max": 50000,
    }, 200)
    assert client.put(f"{HIRING}/saved-jobs/{job['id']}", headers=applicant).status_code == 200
    assert len(client.get(f"{HIRING}/saved-jobs", headers=applicant).json()) == 1
    assert not client.get(f"{HIRING}/saved-jobs", headers=other).json()
    notify = client.get(f"{HIRING}/notifications", headers=applicant).json()[0]
    assert notify["notification_type"] == "job_alert"
    assert client.patch(f"{HIRING}/notifications/{notify['id']}", headers=other).status_code == 404
    assert client.patch(f"{HIRING}/notifications/{notify['id']}", headers=applicant).status_code == 200
    application = {"vacancy_id": job["id"], "cover_letter": "Experienced", "expected_salary": 45000}
    create(client, f"{HIRING}/applications", applicant, application, 422)

    fields = {}
    for field, kind in (("profile_photo_path", "profile_photo"), ("cnic_front_path", "cnic_front"), ("cnic_back_path", "cnic_back")):
        response = client.post(f"{HIRING}/files/{kind}", headers=applicant, files={
            "file": (f"{kind}.png", b"\x89PNG\r\n\x1a\nTEST", "image/png"),
        })
        assert response.status_code == 201, response.text
        file_id = response.json()["id"]
        fields[field] = file_id
        assert client.get(f"{HIRING}/files/{file_id}", headers=other).status_code == 404
        assert client.get(f"{HIRING}/files/{file_id}", headers=hr).content.endswith(b"TEST")

    profile = {"full_name": "Applicant", "father_name": "Family", "cnic": "00000-0000000-0",
               "cnic_name": "Applicant", "whatsapp_number": "03000000000", "education": "Engineering", **fields}
    assert client.put(f"{HIRING}/profile", headers=other, json=profile).status_code == 422
    response = client.put(f"{HIRING}/profile", headers=applicant, json=profile)
    assert response.status_code == 200, response.text
    assert response.json()["is_profile_complete"]
    app_id = create(client, f"{HIRING}/applications", applicant, application)["id"]
    create(client, f"{HIRING}/applications", applicant, application, 409)
    assert client.get(f"{HIRING}/applications/{app_id}/history", headers=other).status_code == 404

    base = f"{HIRING}/hr/applications/{app_id}"
    create(client, f"{base}/notes", hr, {"note": "Private interview preparation"})
    assert client.get(f"{base}/notes", headers=applicant).status_code == 403
    response = client.patch(f"{base}/status", headers=hr, json={"status": "shortlisted"})
    assert response.json()["status"] == "shortlisted"
    create(client, f"{base}/interviews", hr, {
        "scheduled_at": (datetime.now(timezone.utc) + timedelta(days=1)).isoformat(),
        "meeting_url": "https://example.com/meeting",
    })
    assert client.get(f"{HIRING}/interviews/me", headers=applicant).json()[0]["application_id"] == app_id

    thread = create(client, f"{HIRING}/conversations", applicant, {"application_id": app_id}, 200)
    messages = f"{HIRING}/conversations/{thread['id']}/messages"
    create(client, messages, applicant, {"message": "I can attend"})
    assert client.get(messages, headers=other).status_code == 404
    create(client, messages, hr, {"message": "Confirmed"})
    assert [row["message"] for row in client.get(messages, headers=applicant).json()] == ["I can attend", "Confirmed"]
    history = client.get(f"{HIRING}/applications/{app_id}/history", headers=applicant).json()
    assert [row["new_status"] for row in history] == ["applied", "shortlisted", "interview"]

    hire = {"employee_code": f"E-{tag}", "designation": "Engineer"}
    employee = create(client, f"{base}/hire", hr, hire)
    assert create(client, f"{base}/hire", hr, hire) == employee
    assert client.get(f"{API}/auth/me", headers=applicant).status_code == 401
    assert client.get(f"{API}/auth/me", headers=login(client, email)).json()["role"] == "employee"


def test_owner_accounts_invalidate_old_sessions_and_record_activity(session):
    client, owner, tag = session
    owner_api = f"{API}/owner"
    account = create(client, f"{owner_api}/accounts", owner, {
        "full_name": "Accounts manager", "email": f"accounts-{tag}@example.com",
        "role": "accountant", "password": PASSWORD,
    })
    assert "password_hash" not in account
    staff = login(client, account["email"])
    assert client.get(f"{owner_api}/overview", headers=staff).status_code == 403
    assert client.get(f"{owner_api}/accounts", headers=staff).status_code == 403
    assert client.get(f"{owner_api}/activity", headers=staff).status_code == 403

    reset = client.patch(f"{owner_api}/accounts/{account['id']}", headers=owner,
                         json={"password": f"new-{PASSWORD}"})
    assert reset.status_code == 200, reset.text
    assert client.get(f"{API}/auth/me", headers=staff).status_code == 401
    login_result = client.post(f"{API}/auth/login", data={"username": account["email"], "password": f"new-{PASSWORD}"})
    assert login_result.status_code == 200
    new_staff = {"Authorization": "Bearer " + login_result.json()["access_token"]}
    assert client.patch(f"{owner_api}/accounts/{account['id']}", headers=owner, json={"is_active": False}).status_code == 200
    assert client.get(f"{API}/auth/me", headers=new_staff).status_code == 401

    events = client.get(f"{owner_api}/activity", headers=owner).json()
    assert any(event["resource_id"] == account["id"] and event["method"] == "PATCH" for event in events)
    assert PASSWORD not in str(events)
    assert client.get(f"{owner_api}/overview", headers=owner).status_code == 200


def test_owner_approvals_gate_delivery_payment_and_project_signoff(session):
    client, owner, tag = session
    owner_api = f"{API}/owner"
    limits = {"purchase_order_threshold": "250.00", "vendor_payment_threshold": "100.00"}
    response = client.put(f"{owner_api}/approval-settings", headers=owner, json=limits)
    assert response.status_code == 200, response.text

    project = create(client, f"{API}/projects", owner, {"code": f"PA-{tag}", "name": "Project"}, 200)
    material = create(client, f"{TRADE}/materials", owner, {"sku": f"WA-{tag}", "name": "Material"}, 200)
    supplier = create(client, f"{TRADE}/suppliers", owner, {"name": "Supplier"}, 200)
    order = create(client, f"{TRADE}/purchase-orders", owner, {
        "po_number": f"OA-{tag}", "supplier_id": supplier["id"], "project_id": project["id"],
        "order_date": "2026-11-01", "subtotal": 240, "tax_amount": 10, "total_amount": 1,
    }, 200)
    assert order["status"] == "pending_approval"
    delivery = {"purchase_order_id": order["id"], "material_id": material["id"], "quantity": 5}
    create(client, f"{TRADE}/deliveries", owner, delivery, 409)
    approvals = client.get(f"{owner_api}/approvals", headers=owner).json()
    po_id = next(row["id"] for row in approvals if row["record_id"] == order["id"] and row["kind"] == "purchase_order")
    create(client, f"{owner_api}/approvals/{po_id}/approve", owner, {}, 200)
    create(client, f"{TRADE}/deliveries", owner, delivery)

    payment_data = {"supplier_id": supplier["id"], "purchase_order_id": order["id"], "amount": "100.00"}
    queued = create(client, f"{TRADE}/supplier-payments", owner, payment_data)
    assert queued["status"] == "pending_approval"
    assert not any(row["purchase_order_id"] == order["id"] for row in client.get(f"{TRADE}/supplier-payments", headers=owner).json())
    payment_approval = f"{owner_api}/approvals/{queued['approval_id']}/approve"
    create(client, payment_approval, owner, {}, 200)
    create(client, payment_approval, owner, {}, 200)
    assert len([row for row in client.get(f"{TRADE}/supplier-payments", headers=owner).json()
                if row["purchase_order_id"] == order["id"]]) == 1

    for _ in range(2):
        result = client.patch(f"{API}/projects/{project['id']}", headers=owner, json={"status": "completed"})
        assert result.status_code == 200 and result.json()["status"] != "completed"
    signoffs = [row for row in client.get(f"{owner_api}/approvals", headers=owner).json()
                if row["kind"] == "project_signoff" and row["record_id"] == project["id"]]
    assert len(signoffs) == 1
    create(client, f"{owner_api}/approvals/{signoffs[0]['id']}/approve", owner, {}, 200)
    projects = client.get(f"{API}/projects", headers=owner).json()
    assert next(row for row in projects if row["id"] == project["id"])["status"] == "completed"
    client.put(f"{owner_api}/approval-settings", headers=owner, json={})


def test_owner_tender_deadline_margin_and_status(session):
    client, owner, tag = session
    path = f"{API}/owner/tenders"
    data = {
        "reference": f"bid-{tag}", "title": "Site works", "authority": "Procurement office",
        "deadline": "2026-12-31", "bid_amount": "1000.00", "estimated_cost": "750.00",
    }
    row = create(client, path, owner, data)
    assert row["reference"] == f"BID-{tag.upper()}"
    assert row["estimated_margin_percent"] == 25
    assert row["estimated_profit"] == 250
    create(client, path, owner, {**data, "reference": data["reference"].upper()}, 409)
    changed = client.put(f"{path}/{row['id']}", headers=owner, json={**data, "status": "submitted"})
    assert changed.status_code == 200 and changed.json()["status"] == "submitted"
    assert any(item["id"] == row["id"] for item in client.get(f"{path}?status=submitted", headers=owner).json())
    assert all(item["id"] != row["id"] for item in client.get(f"{path}?status=upcoming", headers=owner).json())
    staff = create(client, f"{API}/owner/accounts", owner, {
        "email": f"tender-staff-{tag}@example.com", "full_name": "Staff member", "role": "employee", "password": PASSWORD,
    })
    assert client.get(path, headers=login(client, staff["email"])).status_code == 403
