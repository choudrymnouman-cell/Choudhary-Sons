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


def test_staff_profile_link_preserves_permissions_and_credentials(client):
    uid, email, staff = account(client, 'procurement')
    _, _, hr = account(client, 'hr')
    _, _, owner = account(client, 'owner')
    _, _, finance = account(client, 'accountant')
    pending_id, _, _ = account(client, 'pending')
    body = {'user_id': uid, 'employee_code': uuid4().hex[:20], 'designation': 'Buyer',
            'joining_date': '2026-01-01', 'basic_salary': '50000.00'}
    assert client.post('/api/v1/employees/link-account', headers=finance, json=body).status_code == 403
    assert client.post('/api/v1/employees/link-account', headers=hr, json={**body, 'user_id': pending_id}).status_code == 400
    assert client.post('/api/v1/employees/link-account', headers=hr, json={**body, 'role':'owner'}).status_code == 422
    assert client.post('/api/v1/employees/link-account', headers=hr, json={**body, 'project_id':-1}).status_code == 404
    result = client.post('/api/v1/employees/link-account', headers=hr, json=body)
    assert result.status_code == 201, result.text
    employee_id = result.json()['id']
    assert client.get('/api/v1/auth/me', headers=staff).json()['role'] == 'procurement'
    assert client.post('/api/v1/auth/login', data={'username':email,'password':PASSWORD}).status_code == 200
    assert client.post('/api/v1/employees/link-account', headers=hr, json=body).status_code == 409
    assert uid not in [u['id'] for u in client.get('/api/v1/employees/unlinked-accounts', headers=hr).json()]
    assert client.patch(f'/api/v1/employees/{employee_id}/deactivate', headers=hr).status_code == 403
    assert client.patch(f'/api/v1/employees/{employee_id}', headers=hr, json={'basic_salary':None}).status_code == 422
    assert client.patch(f'/api/v1/employees/{employee_id}/deactivate', headers=owner).status_code == 200
    assert client.get('/api/v1/auth/me', headers=staff).status_code == 401


def test_hr_creation_requires_owner_assignment(client):
    _, _, hr = account(client, 'hr')
    email = f'{uuid4().hex}@example.com'
    result = client.post('/api/v1/employees', headers=hr, json={
        'full_name':'New employee','email':email,'password':PASSWORD,
        'employee_code':uuid4().hex[:20],'designation':'Worker','joining_date':'2026-01-01'})
    assert result.status_code == 201, result.text
    login = client.post('/api/v1/auth/login', data={'username':email,'password':PASSWORD}).json()
    assert login['user']['role'] == 'pending'


def test_payroll_payment_validation_and_leave_review(client):
    uid, _, employee = account(client, 'employee')
    _, _, hr = account(client, 'hr')
    _, _, finance = account(client, 'accountant')
    body = {'user_id':uid,'employee_code':uuid4().hex[:20],'designation':'Worker','joining_date':'2026-01-01'}
    employee_id = client.post('/api/v1/employees/link-account',headers=hr,json=body).json()['id']
    payroll = {'employee_id':employee_id,'period':'2026-11','basic_salary':'1000.10','overtime':'20.20','deductions':'10.10'}
    for bad in ({'period':'2026-13'},{'basic_salary':-1},{'deductions':2000},{'payment_status':'paid'}):
        assert client.post('/api/v1/payroll',headers=hr,json={**payroll,**bad}).status_code == 422
    result = client.post('/api/v1/payroll',headers=hr,json=payroll)
    assert result.status_code == 200, result.text
    assert float(result.json()['net_salary']) == 1010.20
    pid = result.json()['id']
    assert client.post('/api/v1/payroll',headers=hr,json=payroll).status_code == 409
    assert client.post(f'/api/v1/payroll/{pid}/pay',headers=hr,json={'reference':'Cash 1'}).status_code == 403
    assert client.post(f'/api/v1/payroll/{pid}/pay',headers=finance,json={'reference':'Cash 1'}).status_code == 200
    assert client.post(f'/api/v1/payroll/{pid}/pay',headers=finance,json={'reference':'Cash 2'}).status_code == 409
    leave = {'start_date':'2026-11-20','end_date':'2026-11-22'}
    result = client.post('/api/v1/leave',headers=employee,json=leave)
    assert result.status_code == 200
    lid = result.json()['id']
    assert client.post('/api/v1/leave',headers=employee,json=leave).status_code == 409
    assert client.patch(f'/api/v1/leave/{lid}/approved',headers=hr).status_code == 200
    assert client.patch(f'/api/v1/leave/{lid}/rejected',headers=hr).status_code == 409


def test_project_schedule_and_safety_are_scoped(client):
    _, _, owner = account(client, 'owner')
    uid, email, _ = account(client, 'site_supervisor')
    _, _, finance = account(client, 'accountant')
    projects = [client.post('/api/v1/projects',headers=owner,json={'code':uuid4().hex,'name':'Scheduled site'}).json()['id'] for _ in range(2)]
    client.patch(f'/api/v1/owner/accounts/{uid}',headers=owner,json={'project_ids':[projects[0]]})
    staff = {'Authorization':'Bearer '+client.post('/api/v1/auth/login',data={'username':email,'password':PASSWORD}).json()['access_token']}
    body = {'project_id':projects[0],'title':'Foundation complete','kind':'milestone','start_date':'2026-01-01','due_date':'2026-01-10'}
    assert client.post('/api/v1/planning/tasks',headers=staff,json=body).status_code == 403
    assert client.post('/api/v1/planning/tasks',headers=owner,json={**body,'due_date':'2025-12-01'}).status_code == 422
    task = client.post('/api/v1/planning/tasks',headers=owner,json=body)
    assert task.status_code == 201, task.text
    tid = task.json()['id']
    other = client.post('/api/v1/planning/tasks',headers=owner,json={**body,'project_id':projects[1]}).json()['id']
    assert [t['id'] for t in client.get('/api/v1/planning/tasks',headers=staff).json()] == [tid]
    update = {'progress':100,'status':'completed'}
    assert client.patch(f'/api/v1/planning/tasks/{other}/progress',headers=staff,json=update).status_code == 403
    assert client.patch(f'/api/v1/planning/tasks/{tid}/progress',headers=finance,json=update).status_code == 403
    assert client.patch(f'/api/v1/planning/tasks/{tid}/progress',headers=staff,json={**update,'progress':90}).status_code == 422
    assert client.patch(f'/api/v1/planning/tasks/{tid}/progress',headers=staff,json=update).status_code == 200
    incident = client.post('/api/v1/safety/incidents',headers=staff,json={'project_id':projects[0],'title':'Open edge','description':'Missing guardrail'}).json()
    close = f"/api/v1/safety/incidents/{incident['id']}/close"
    assert client.post(close,headers=staff,json={'corrective_action':'Installed guardrail'}).status_code == 403
    assert client.post(close,headers=owner,json={'corrective_action':'Installed guardrail'}).status_code == 200
    assert client.post(close,headers=owner,json={'corrective_action':'Installed guardrail'}).status_code == 409
    inspection = {'project_id':projects[0],'inspector':'Supervisor','score':90}
    assert client.post('/api/v1/safety/inspections',headers=staff,json={**inspection,'score':101}).status_code == 422
    assert client.post('/api/v1/safety/inspections',headers=staff,json=inspection).status_code == 200
    assert {r['project_id'] for r in client.get('/api/v1/safety/inspections',headers=staff).json()} == {projects[0]}


def test_fuel_validation_and_service_alerts(client):
    _, _, fleet = account(client, 'equipment')
    asset = client.post('/api/v1/assets',headers=fleet,json={'asset_code':uuid4().hex,'name':'Excavator','asset_type':'excavator','current_meter':100}).json()
    aid = asset['id']
    fuel = {'asset_id':aid,'liters':'10.50','rate_per_liter':'250.25','meter_reading':101}
    assert client.post('/api/v1/assets/fuel',headers=fleet,json={**fuel,'liters':-1}).status_code == 422
    assert client.post('/api/v1/assets/fuel',headers=fleet,json={**fuel,'meter_reading':99}).status_code == 409
    assert client.post('/api/v1/assets/fuel',headers=fleet,json=fuel).status_code == 200
    assert len(client.get(f'/api/v1/assets/fuel?asset_id={aid}',headers=fleet).json()) == 1
    service = {'asset_id':aid,'maintenance_type':'Oil change','description':'Replaced oil','next_due_meter':100}
    assert client.post('/api/v1/assets/maintenance',headers=fleet,json=service).status_code == 200
    assert aid in [r['asset_id'] for r in client.get('/api/v1/assets/maintenance-due',headers=fleet).json()]
    assert client.post('/api/v1/assets/maintenance',headers=fleet,json={**service,'next_due_meter':200}).status_code == 200
    assert aid not in [r['asset_id'] for r in client.get('/api/v1/assets/maintenance-due',headers=fleet).json()]


def test_material_requisition_order_and_owner_approval(client):
    _, _, owner = account(client, 'owner')
    _, _, procurement = account(client, 'procurement')
    _, _, finance = account(client, 'accountant')
    pid = client.post('/api/v1/projects',headers=owner,json={'code':uuid4().hex,'name':'Supply site'}).json()['id']
    mid = client.post('/api/v1/commercial/materials',headers=procurement,json={'sku':uuid4().hex,'name':'Cement','unit':'bags'}).json()['id']
    sid = client.post('/api/v1/commercial/suppliers',headers=procurement,json={'name':'Supplier'}).json()['id']
    body = {'project_id':pid,'material_id':mid,'quantity':'10','needed_by':'2026-12-01','purpose':'Foundation'}
    assert client.post('/api/v1/requisitions',headers=procurement,json=body).status_code == 403
    result = client.post('/api/v1/requisitions',headers=owner,json=body)
    assert result.status_code == 201, result.text
    rid = result.json()['id']
    client.put('/api/v1/owner/approval-settings',headers=owner,json={'purchase_order_threshold':100})
    po = {'supplier_id':sid,'po_number':uuid4().hex,'unit_price':'50','tax_amount':'20'}
    assert client.post(f'/api/v1/requisitions/{rid}/order',headers=finance,json=po).status_code == 403
    result = client.post(f'/api/v1/requisitions/{rid}/order',headers=procurement,json=po)
    assert result.status_code == 201, result.text
    assert float(result.json()['total_amount']) == 520
    assert result.json()['status'] == 'pending_approval'
    assert client.post(f'/api/v1/requisitions/{rid}/order',headers=procurement,json=po).status_code == 409
    assert client.post(f'/api/v1/requisitions/{rid}/cancel',headers=owner).status_code == 409
    approval = next(r for r in client.get('/api/v1/owner/approvals',headers=owner).json() if r['kind']=='purchase_order' and r['record_id']==result.json()['id'])
    assert client.post(f"/api/v1/owner/approvals/{approval['id']}/approve",headers=owner).status_code == 200
