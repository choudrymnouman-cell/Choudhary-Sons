from datetime import date
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from decimal import Decimal
from typing import Literal
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_roles
from app.api.project_access import project_query, require_project
from app.core.config import settings
from app.models.commercial import ClientInvoice, Expense, PurchaseOrder
from app.models.core import Attendance, Employee, Project, ProjectStatus, User, UserRole
from app.models.field_ops import (
    Asset,
    CompanyDocument,
    FuelLog,
    MaintenanceLog,
    Notice,
    SafetyIncident,
    SafetyInspection,
    SiteDailyReport,
)
from app.models.operations import JobApplication, JobVacancy, LeaveRequest, PayrollRecord

router = APIRouter(tags=["field-operations"])

MANAGEMENT = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.HR,
    UserRole.ACCOUNTANT,
    UserRole.PROJECT_MANAGER,
    UserRole.SITE_SUPERVISOR,
]
FIELD_MANAGEMENT = [UserRole.OWNER, UserRole.ADMIN, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR]
DOCUMENT_MANAGEMENT = [UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.ACCOUNTANT, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR]
ALLOWED_DOCUMENT_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".doc", ".docx", ".xls", ".xlsx"}


class AssetCreate(BaseModel):
    asset_code: str
    name: str
    asset_type: str
    registration_number: str | None = None
    make_model: str | None = None
    project_id: int | None = None
    current_meter: Decimal = Field(default=Decimal("0"), ge=0)
    notes: str | None = None


class FuelCreate(BaseModel):
    asset_id: int
    project_id: int | None = None
    liters: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    rate_per_liter: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    meter_reading: Decimal | None = Field(default=None, ge=0)
    vendor: str | None = None


class MaintenanceCreate(BaseModel):
    asset_id: int
    maintenance_type: str
    description: str
    cost: Decimal = Field(default=Decimal("0"), ge=0, max_digits=14, decimal_places=2)
    vendor: str | None = None
    next_due_date: date | None = None
    next_due_meter: Decimal | None = Field(default=None, ge=0)


class DailyReportCreate(BaseModel):
    project_id: int
    weather: str | None = None
    workforce_count: int = Field(default=0, ge=0)
    work_completed: str
    materials_used: str | None = None
    equipment_used: str | None = None
    delays_issues: str | None = None
    tomorrow_plan: str | None = None


class IncidentCreate(BaseModel):
    project_id: int | None = None
    severity: Literal["minor", "moderate", "major", "critical"] = "minor"
    title: str
    description: str
    injured_person: str | None = None
    corrective_action: str | None = None


class InspectionCreate(BaseModel):
    project_id: int
    inspector: str
    score: float | None = Field(default=None, ge=0, le=100)
    findings: str | None = None
    action_required: str | None = None


class NoticeCreate(BaseModel):
    title: str
    body: str
    audience: str = "all"


@router.get("/assets")
def list_assets(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    return db.query(Asset).order_by(Asset.name).all()


@router.post("/assets")
def create_asset(payload: AssetCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    if db.query(Asset).filter(Asset.asset_code == payload.asset_code).first():
        raise HTTPException(status_code=409, detail="Asset code already exists")
    require_project(db, _, payload.project_id)
    asset = Asset(**payload.model_dump())
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset


@router.post("/assets/fuel")
def add_fuel(payload: FuelCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    asset = db.get(Asset, payload.asset_id, with_for_update=True)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    require_project(db, _, payload.project_id)
    if payload.meter_reading is not None and payload.meter_reading < asset.current_meter:
        raise HTTPException(409, "Meter reading cannot go backwards")
    log = FuelLog(**payload.model_dump(), total_cost=payload.liters * payload.rate_per_liter)
    if payload.meter_reading is not None:
        asset.current_meter = payload.meter_reading
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.post("/assets/maintenance")
def add_maintenance(payload: MaintenanceCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    if not db.get(Asset, payload.asset_id):
        raise HTTPException(status_code=404, detail="Asset not found")
    log = MaintenanceLog(**payload.model_dump())
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.get("/assets/fuel")
def fuel_history(asset_id: int | None = None, db: Session = Depends(get_db),
                 _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    query = db.query(FuelLog)
    if asset_id is not None:
        query = query.filter(FuelLog.asset_id == asset_id)
    return query.order_by(FuelLog.log_date.desc(), FuelLog.id.desc()).all()


@router.get("/assets/maintenance")
def maintenance_history(asset_id: int | None = None, db: Session = Depends(get_db),
                        _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    query = db.query(MaintenanceLog)
    if asset_id is not None:
        query = query.filter(MaintenanceLog.asset_id == asset_id)
    return query.order_by(MaintenanceLog.maintenance_date.desc(), MaintenanceLog.id.desc()).all()


@router.get("/assets/maintenance-due")
def maintenance_due(db: Session = Depends(get_db),
                    _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    # Only the latest service of each type determines the next due date.
    latest = db.query(func.max(MaintenanceLog.id)).group_by(MaintenanceLog.asset_id, MaintenanceLog.maintenance_type)
    rows = db.query(MaintenanceLog, Asset).join(Asset, Asset.id == MaintenanceLog.asset_id).filter(MaintenanceLog.id.in_(latest)).all()
    return [{"asset_id": a.id, "name": a.name, "maintenance_type": m.maintenance_type,
             "next_due_date": m.next_due_date, "next_due_meter": m.next_due_meter, "current_meter": a.current_meter}
            for m, a in rows if (m.next_due_date and m.next_due_date <= date.today())
            or (m.next_due_meter is not None and a.current_meter >= m.next_due_meter)]


@router.get("/assets/cost-summary")
def asset_cost_summary(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.EQUIPMENT))):
    fuel_cost = db.query(func.coalesce(func.sum(FuelLog.total_cost), 0)).scalar()
    maintenance_cost = db.query(func.coalesce(func.sum(MaintenanceLog.cost), 0)).scalar()
    return {
        "asset_count": db.query(Asset).count(),
        "fuel_cost": float(fuel_cost or 0),
        "maintenance_cost": float(maintenance_cost or 0),
        "total_asset_operating_cost": float((fuel_cost or 0) + (maintenance_cost or 0)),
    }


@router.post("/site-reports")
def create_site_report(payload: DailyReportCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    if not db.get(Project, payload.project_id):
        raise HTTPException(status_code=404, detail="Project not found")
    require_project(db, user, payload.project_id)
    report = SiteDailyReport(**payload.model_dump(), submitted_by=user.id)
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get("/site-reports")
def list_site_reports(project_id: int | None = None, db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    query = project_query(db.query(SiteDailyReport), SiteDailyReport.project_id, db, user)
    if project_id is not None:
        query = query.filter(SiteDailyReport.project_id == project_id)
    return query.order_by(SiteDailyReport.report_date.desc()).all()


@router.post("/safety/incidents")
def create_incident(payload: IncidentCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    require_project(db, user, payload.project_id)
    incident = SafetyIncident(**payload.model_dump(), reported_by=user.id)
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return incident


@router.get("/safety/incidents")
def list_incidents(db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    return project_query(db.query(SafetyIncident), SafetyIncident.project_id, db, user).order_by(SafetyIncident.incident_date.desc()).all()


@router.post("/safety/inspections")
def create_inspection(payload: InspectionCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    require_project(db, user, payload.project_id)
    inspection = SafetyInspection(**payload.model_dump())
    db.add(inspection)
    db.commit()
    db.refresh(inspection)
    return inspection


@router.get("/safety/inspections")
def inspections(db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    return project_query(db.query(SafetyInspection), SafetyInspection.project_id, db, user).order_by(SafetyInspection.id.desc()).all()


class IncidentResolution(BaseModel):
    corrective_action: str = Field(min_length=5, max_length=10000)


@router.post("/safety/incidents/{incident_id}/close")
def close_incident(incident_id: int, payload: IncidentResolution, db: Session = Depends(get_db),
                   user: User = Depends(require_roles(UserRole.OWNER, UserRole.PROJECT_MANAGER))):
    incident = db.get(SafetyIncident, incident_id, with_for_update=True)
    if not incident:
        raise HTTPException(404, "Incident not found")
    require_project(db, user, incident.project_id)
    if incident.is_closed:
        raise HTTPException(409, "Incident has already been closed")
    incident.corrective_action = payload.corrective_action
    incident.is_closed = True
    db.commit()
    db.refresh(incident)
    return incident


@router.post("/documents", status_code=201)
async def upload_document(
    title: str = Form(...),
    document_type: str = Form(...),
    project_id: int | None = Form(None),
    employee_id: int | None = Form(None),
    expiry_date: date | None = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DOCUMENT_MANAGEMENT)),
):
    if project_id is not None and not db.get(Project, project_id):
        raise HTTPException(status_code=404, detail="Project not found")
    if employee_id is not None and not db.get(Employee, employee_id):
        raise HTTPException(status_code=404, detail="Employee not found")
    if project_id is None and employee_id is None:
        raise HTTPException(status_code=400, detail="Attach the document to a project or employee")

    require_project(db, user, project_id)
    original_name = Path(file.filename or "upload").name
    extension = Path(original_name).suffix.lower()
    if extension not in ALLOWED_DOCUMENT_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported file type")

    max_bytes = settings.max_upload_mb * 1024 * 1024
    contents = await file.read(max_bytes + 1)
    if len(contents) > max_bytes:
        raise HTTPException(status_code=413, detail=f"File exceeds {settings.max_upload_mb} MB limit")

    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    stored_name = f"{uuid4().hex}{extension}"
    stored_path = upload_dir / stored_name
    stored_path.write_bytes(contents)

    document = CompanyDocument(
        project_id=project_id,
        employee_id=employee_id,
        title=title.strip(),
        document_type=document_type.strip(),
        file_url=f"/uploads/{stored_name}",
        expiry_date=expiry_date,
        uploaded_by=user.id,
    )
    db.add(document)
    try:
        db.commit()
    except Exception:
        db.rollback()
        stored_path.unlink(missing_ok=True)
        raise
    db.refresh(document)
    return document


@router.get("/documents")
def list_documents(
    project_id: int | None = None,
    employee_id: int | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DOCUMENT_MANAGEMENT)),
):
    query = project_query(db.query(CompanyDocument), CompanyDocument.project_id, db, user)
    if user.role != UserRole.OWNER:
        query = query.filter(CompanyDocument.uploaded_by == user.id)
    if project_id is not None:
        query = query.filter(CompanyDocument.project_id == project_id)
    if employee_id is not None:
        query = query.filter(CompanyDocument.employee_id == employee_id)
    return query.order_by(CompanyDocument.created_at.desc()).all()


@router.post("/notices")
def create_notice(payload: NoticeCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    notice = Notice(**payload.model_dump(), created_by=user.id)
    db.add(notice)
    db.commit()
    db.refresh(notice)
    return notice


@router.get("/notices")
def list_notices(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role == UserRole.APPLICANT:
        raise HTTPException(403, "Staff access required")
    query = db.query(Notice).filter(Notice.is_active.is_(True))
    if user.role not in {UserRole.OWNER, UserRole.HR, UserRole.ADMIN}:
        query = query.filter(Notice.audience.in_(["all", user.role.value]))
    return query.order_by(Notice.created_at.desc()).limit(50).all()


@router.get("/dashboard/kpis")
def dashboard_kpis(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER))):
    today = date.today()
    active_projects = db.query(Project).filter(Project.status == ProjectStatus.ACTIVE).count()
    employee_count = db.query(Employee).count()
    present_today = db.query(Attendance).filter(Attendance.attendance_date == today).count()
    open_jobs = db.query(JobVacancy).filter(JobVacancy.is_open.is_(True)).count()
    pending_applications = db.query(JobApplication).count()
    pending_leaves = db.query(LeaveRequest).filter(LeaveRequest.status == "PENDING").count()
    payroll_pending = db.query(PayrollRecord).filter(PayrollRecord.payment_status == "pending").count()
    open_incidents = db.query(SafetyIncident).filter(SafetyIncident.is_closed.is_(False)).count()
    purchase_orders = db.query(PurchaseOrder).count()
    expenses = float(db.query(func.coalesce(func.sum(Expense.amount), 0)).scalar() or 0)
    invoiced = float(db.query(func.coalesce(func.sum(ClientInvoice.total_amount), 0)).scalar() or 0)
    received = float(db.query(func.coalesce(func.sum(ClientInvoice.paid_amount), 0)).scalar() or 0)
    return {
        "active_projects": active_projects,
        "employees": employee_count,
        "present_today": present_today,
        "open_jobs": open_jobs,
        "applications": pending_applications,
        "pending_leaves": pending_leaves,
        "pending_payroll": payroll_pending,
        "open_safety_incidents": open_incidents,
        "purchase_orders": purchase_orders,
        "total_expenses": expenses,
        "total_invoiced": invoiced,
        "cash_received": received,
        "receivables": invoiced - received,
    }
