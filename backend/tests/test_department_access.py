"""Exercise real authentication, role boundaries and owner assignment."""
from uuid import uuid4
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.session import SessionLocal
from app.models.core import User, UserRole
from app.core.security import hash_password

PASSWORD = 'department-test-password'

@pytest.fixture
def client():
    with TestClient(app) as client:
        yield client


def account(client, role):
    email = f'{role}-{uuid4().hex}@example.com'
    with SessionLocal() as db:
        user = User(full_name='Role test', email=email, role=UserRole(role), password_hash=hash_password(PASSWORD))
        db.add(user)
        db.commit()
        uid = user.id
    result = client.post('/api/v1/auth/login', data={'username':email,'password':PASSWORD})
    assert result.status_code == 200
    return uid, email, {'Authorization': 'Bearer '+result.json()['access_token']}


@pytest.mark.parametrize('role,allowed,denied', [
    ('hr', '/employees', '/commercial/invoices'),
    ('accountant', '/commercial/invoices', '/site-reports'),
    ('procurement', '/commercial/purchase-orders', '/payroll'),
    ('store', '/commercial/materials', '/commercial/supplier-payments'),
    ('project_manager', '/site-reports', '/owner/overview'),
    ('site_supervisor', '/site-reports', '/employees'),
    ('estimator', '/owner/tenders', '/commercial/invoices'),
    ('equipment', '/assets', '/employees'),
    ('admin', '/employees', '/owner/accounts'),
    ('employee', '/auth/me', '/commercial/materials'),
    ('applicant', '/auth/me', '/owner/accounts'),
    ('pending', '/auth/me', '/projects'),
])
def test_department_boundaries(client, role, allowed, denied):
    _, _, headers = account(client,role)
    assert client.get('/api/v1'+allowed,headers=headers).status_code == 200
    assert client.get('/api/v1'+denied,headers=headers).status_code == 403
    if role != 'owner':
        assert client.patch('/api/v1/owner/accounts/1',headers=headers,json={'role':'owner'}).status_code == 403


def test_registration_owner_assignment_and_revocation(client):
    email=f'pending-{uuid4().hex}@example.com'
    body={'email':email,'full_name':'New colleague','password':PASSWORD}
    assert client.post('/api/v1/auth/signup', json={**body,'role':'owner'}).status_code == 422
    assert client.post('/api/v1/auth/signup', json=body).status_code == 201
    login=lambda: client.post('/api/v1/auth/login',data={'username':email,'password':PASSWORD}).json()
    pending=login()
    assert pending['user']['role'] == 'pending'
    headers={'Authorization':'Bearer '+pending['access_token']}
    assert client.get('/api/v1/employees',headers=headers).status_code == 403
    _, _, owner=account(client,'owner')
    uid=pending['user']['id']
    assert client.patch(f'/api/v1/owner/accounts/{uid}', headers=owner,json={'role':'hr'}).status_code == 200
    assert client.get('/api/v1/auth/me',headers=headers).status_code == 401
    hr=login()
    headers={'Authorization':'Bearer '+hr['access_token']}
    assert client.get('/api/v1/employees',headers=headers).status_code == 200
    assert client.get('/api/v1/commercial/expenses',headers=headers).status_code == 403
    assert client.patch(f'/api/v1/owner/accounts/{uid}',headers=owner,json={'is_active':False}).status_code == 200
    assert client.get('/api/v1/employees',headers=headers).status_code == 401


def test_finance_and_store_cannot_change_purchase_orders(client):
    for role in ('accountant','store'):
        _, _, headers=account(client,role)
        assert client.post('/api/v1/commercial/purchase-orders',headers=headers,json={}).status_code == 403
    _, _, finance=account(client,'accountant')
    assert client.post('/api/v1/commercial/boq',headers=finance,json={}).status_code == 403


def test_owner_can_enter_every_department(client):
    _, _, headers=account(client,'owner')
    for route in ('/employees','/payroll','/commercial/purchase-orders','/commercial/materials',
                  '/commercial/invoices','/site-reports','/assets','/owner/tenders','/owner/accounts','/owner/overview'):
        response=client.get('/api/v1'+route,headers=headers)
        assert response.status_code==200, (route,response.text)

@pytest.mark.parametrize('role', ['project_manager', 'site_supervisor'])
def test_project_assignment_boundaries(client, role):
    _, _, owner = account(client, 'owner')
    uid, email, staff = account(client, role)
    projects = []
    for _ in range(2):
        r = client.post('/api/v1/projects', headers=owner, json={'code':uuid4().hex,'name':'Test site'})
        assert r.status_code == 200
        projects.append(r.json()['id'])
    assert client.get('/api/v1/projects', headers=staff).json() == []
    r = client.patch(f'/api/v1/owner/accounts/{uid}', headers=owner, json={'project_ids':[projects[0]]})
    assert r.status_code == 200
    assert r.json()['project_ids'] == [projects[0]]
    assert client.get('/api/v1/auth/me', headers=staff).status_code == 401
    token = client.post('/api/v1/auth/login', data={'username':email,'password':PASSWORD}).json()['access_token']
    staff = {'Authorization':'Bearer '+token}
    assert [p['id'] for p in client.get('/api/v1/projects', headers=staff).json()] == [projects[0]]
    for pid in projects:
        r = client.post('/api/v1/site-reports', headers=staff, json={'project_id':pid,'work_completed':'Site work'})
        assert r.status_code == (200 if pid == projects[0] else 403)
    assert {r['project_id'] for r in client.get('/api/v1/site-reports', headers=staff).json()} == {projects[0]}
    if role == 'project_manager':
        assert client.get(f'/api/v1/commercial/boq/{projects[1]}', headers=staff).status_code == 403
        assert client.patch(f'/api/v1/projects/{projects[1]}', headers=staff,json={'name':'Forbidden'}).status_code == 403
    assert client.patch(f'/api/v1/owner/accounts/{uid}', headers=owner,json={'project_ids':[-1]}).status_code == 422
    assert [p['id'] for p in client.get('/api/v1/projects', headers=staff).json()] == [projects[0]]
