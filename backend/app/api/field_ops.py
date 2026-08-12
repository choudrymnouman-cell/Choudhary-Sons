from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_roles
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


class AssetCreate(BaseModel):
    asset_code: str
    name: str
    asset_type: str
    registration_number: str | None = None
    make_model: str | None = None
    project_id: int | None = None
    current_meter: float = 0
    notes: str | None = None


class FuelCreate(BaseModel):
    asset_id: int
    project_id: int | None = None
    liters: float
    rate_per_liter: float
    meter_reading: float | None = None
    vendor: str | None = None


class MaintenanceCreate(BaseModel):
    asset_id: int
    maintenance_type: str
    description: str
    cost: float = 0
    vendor: str | None = None
    next_due_date: date | None = None
    next_due_meter: float | None = None


class DailyReportCreate(BaseModel):
    project_id: int
    weather: str | None = None
    workforce_count: int = 0
    work_completed: str
    materials_used: str | None = None
    equipment_used: str | None = None
    delays_issues: str | None = None
    tomorrow_plan: str | None = None


class IncidentCreate(BaseModel):
    project_id: int | None = None
    severity: str = "minor"
    title: str
    description: str
    injured_person: str | None = None
    corrective_action: str | None = None


class InspectionCreate(BaseModel):
    project_id: int
    inspector: str
    score: float | None = None
    findings: str | None = None
    action_required: str | None = None


class NoticeCreate(BaseModel):
    title: str
    body: str
    audience: str = "all"


@router.get("/assets")
def list_assets(db: Session = Depends(get_db), _: User = Depends(require_roles(*MANAGEMENT))):
    return db.query(Asset).order_by(Asset.name).all()


@router.post("/assets")
def create_asset(payload: AssetCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    if db.query(Asset).filter(Asset.asset_code == payload.asset_code).first():
        raise HTTPException(status_code=409, detail="Asset code already exists")
    asset = Asset(**payload.model_dump())
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset


@router.post("/assets/fuel")
def add_fuel(payload: FuelCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    asset = db.get(Asset, payload.asset_id)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    log = FuelLog(**payload.model_dump(), total_cost=payload.liters * payload.rate_per_liter)
    if payload.meter_reading is not None:
        asset.current_meter = payload.meter_reading
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.post("/assets/maintenance")
def add_maintenance(payload: MaintenanceCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    if not db.get(Asset, payload.asset_id):
        raise HTTPException(status_code=404, detail="Asset not found")
    log = MaintenanceLog(**payload.model_dump())
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.get("/assets/cost-summary")
def asset_cost_summary(db: Session = Depends(get_db), _: User = Depends(require_roles(*MANAGEMENT))):
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
    report = SiteDailyReport(**payload.model_dump(), submitted_by=user.id)
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get("/site-reports")
def list_site_reports(project_id: int | None = None, db: Session = Depends(get_db), _: User = Depends(require_roles(*MANAGEMENT))):
    query = db.query(SiteDailyReport)
    if project_id is not None:
        query = query.filter(SiteDailyReport.project_id == project_id)
    return query.order_by(SiteDailyReport.report_date.desc()).all()


@router.post("/safety/incidents")
def create_incident(payload: IncidentCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    incident = SafetyIncident(**payload.model_dump(), reported_by=user.id)
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return incident


@router.get("/safety/incidents")
def list_incidents(db: Session = Depends(get_db), _: User = Depends(require_roles(*MANAGEMENT))):
    return db.query(SafetyIncident).order_by(SafetyIncident.incident_date.desc()).all()


@router.post("/safety/inspections")
def create_inspection(payload: InspectionCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(*FIELD_MANAGEMENT))):
    inspection = SafetyInspection(**payload.model_dump())
    db.add(inspection)
    db.commit()
    db.refresh(inspection)
    return inspection


@router.post("/notices")
def create_notice(payload: NoticeCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    notice = Notice(**payload.model_dump(), created_by=user.id)
    db.add(notice)
    db.commit()
    db.refresh(notice)
    return notice


@router.get("/notices")
def list_notices(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    query = db.query(Notice).filter(Notice.is_active.is_(True))
    return query.order_by(Notice.created_at.desc()).limit(50).all()


@router.get("/dashboard/kpis")
def dashboard_kpis(db: Session = Depends(get_db), _: User = Depends(require_roles(*MANAGEMENT))):
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
