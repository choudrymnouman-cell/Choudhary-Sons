from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, Field, model_validator
from decimal import Decimal
from typing import Literal
from sqlalchemy.orm import Session

from sqlalchemy import select

from app.api.approvals import queue_request
from app.api.deps import get_current_user, require_roles
from app.api.project_access import project_query, require_project
from app.api.recruitment import notify_matching_jobs
from app.db.session import get_db
from app.models.core import Employee, Project, ProjectStatus, User, UserRole, UserProjectAssignment
from app.models.ownership import ApprovalRequest
from app.models.operations import ApplicationStatus, JobApplication, JobVacancy, LeaveRequest, LeaveStatus, PayrollRecord

router = APIRouter(tags=["operations"])


class ProjectCreate(BaseModel):
    code: str
    name: str
    description: str | None = None
    site_address: str | None = None
    contract_value: float = 0


class ProjectUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    site_address: str | None = None
    contract_value: float | None = None
    status: ProjectStatus | None = None
    start_date: date | None = None
    end_date: date | None = None


@router.get("/projects")
def list_projects(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role not in {UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR, UserRole.PROCUREMENT, UserRole.STORE, UserRole.ESTIMATOR, UserRole.EQUIPMENT, UserRole.HR}:
        raise HTTPException(403, "Project access required")
    rows = project_query(db.query(Project), Project.id, db, user).order_by(Project.id.desc()).all()
    if user.role in {UserRole.PROCUREMENT, UserRole.STORE, UserRole.EQUIPMENT, UserRole.SITE_SUPERVISOR, UserRole.HR}:
        return [{"id": p.id, "name": p.name, "code": p.code, "status": p.status, "site_address": p.site_address} for p in rows]
    return rows


@router.post("/projects")
def create_project(payload: ProjectCreate, db: Session = Depends(get_db), actor: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.PROJECT_MANAGER))):
    if db.query(Project).filter(Project.code == payload.code).first():
        raise HTTPException(status_code=409, detail="Project code already exists")
    project = Project(**payload.model_dump())
    db.add(project)
    db.flush()
    if actor.role == UserRole.PROJECT_MANAGER:
        db.add(UserProjectAssignment(user_id=actor.id, project_id=project.id))
    db.commit()
    db.refresh(project)
    return project


@router.patch("/projects/{project_id}")
def update_project(project_id: int, payload: ProjectUpdate, db: Session = Depends(get_db), actor: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.PROJECT_MANAGER))):
    require_project(db, actor, project_id)
    project = db.get(Project, project_id, with_for_update=True)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    data = payload.model_dump(exclude_unset=True)
    start = data.get("start_date", project.start_date)
    end = data.get("end_date", project.end_date)
    if start and end and end < start:
        raise HTTPException(status_code=400, detail="End date cannot be before start date")
    awaiting_signoff = data.get("status") == ProjectStatus.COMPLETED and project.status != ProjectStatus.COMPLETED
    if awaiting_signoff:
        if project.status == ProjectStatus.CANCELLED:
            raise HTTPException(409, "Cancelled projects cannot be signed off")
        data.pop("status")
        pending = db.scalar(select(ApprovalRequest.id).where(
            ApprovalRequest.kind == "project_signoff", ApprovalRequest.record_id == project.id,
            ApprovalRequest.status == "pending",
        ))
        if pending is None:
            queue_request(db, kind="project_signoff", user_id=actor.id,
                          description=f"Sign off project {project.code}", record_id=project.id)
    for key, value in data.items():
        setattr(project, key, value)
    db.commit()
    db.refresh(project)
    return {**vars(project), "approval_pending": True} if awaiting_signoff else project


class VacancyCreate(BaseModel):
    title: str
    department: str | None = None
    location: str | None = None
    employment_type: str = "full_time"
    description: str
    salary_min: float | None = None
    salary_max: float | None = None


@router.get("/jobs")
def public_jobs(db: Session = Depends(get_db)):
    return db.query(JobVacancy).filter(JobVacancy.is_open.is_(True)).order_by(JobVacancy.id.desc()).all()


@router.post("/jobs")
def create_job(payload: VacancyCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    job = JobVacancy(**payload.model_dump())
    db.add(job)
    db.flush()
    notify_matching_jobs(db, job)
    db.commit()
    db.refresh(job)
    return job


@router.patch("/jobs/{job_id}/close")
def close_job(job_id: int, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    job = db.get(JobVacancy, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Vacancy not found")
    job.is_open = False
    db.commit()
    db.refresh(job)
    return job


class JobApply(BaseModel):
    vacancy_id: int
    applicant_name: str
    email: EmailStr
    phone: str | None = None
    cnic: str | None = None
    experience_years: float | None = None
    cover_note: str | None = None


@router.post("/jobs/apply")
def apply_job(payload: JobApply, db: Session = Depends(get_db)):
    job = db.get(JobVacancy, payload.vacancy_id)
    if not job or not job.is_open:
        raise HTTPException(status_code=404, detail="Vacancy is not open")
    application = JobApplication(**payload.model_dump())
    db.add(application)
    db.commit()
    db.refresh(application)
    return application


@router.get("/job-applications")
def applications(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    return db.query(JobApplication).order_by(JobApplication.id.desc()).all()


class LeaveCreate(BaseModel):
    leave_type: str = "annual"
    start_date: date
    end_date: date
    reason: str | None = None


@router.post("/leave")
def request_leave(payload: LeaveCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    employee = db.query(Employee).filter(Employee.user_id == user.id).first()
    if not employee:
        raise HTTPException(status_code=400, detail="Employee profile required")
    if payload.end_date < payload.start_date:
        raise HTTPException(status_code=400, detail="End date cannot be before start date")
    if db.query(LeaveRequest).filter(LeaveRequest.employee_id == employee.id,
            LeaveRequest.status != LeaveStatus.REJECTED, LeaveRequest.start_date <= payload.end_date,
            LeaveRequest.end_date >= payload.start_date).first():
        raise HTTPException(409, "An overlapping leave request already exists")
    leave = LeaveRequest(employee_id=employee.id, **payload.model_dump())
    db.add(leave)
    db.commit()
    db.refresh(leave)
    return leave


@router.get("/leave/me")
def my_leave(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    employee = db.query(Employee).filter(Employee.user_id == user.id).first()
    if not employee:
        return []
    return db.query(LeaveRequest).filter(LeaveRequest.employee_id == employee.id).order_by(LeaveRequest.id.desc()).all()


@router.get("/leave")
def all_leave(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    return db.query(LeaveRequest).order_by(LeaveRequest.id.desc()).all()


@router.patch("/leave/{leave_id}/{decision}")
def review_leave(leave_id: int, decision: str, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR))):
    leave = db.get(LeaveRequest, leave_id, with_for_update=True)
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")
    if decision not in {"approved", "rejected"}:
        raise HTTPException(status_code=400, detail="Decision must be approved or rejected")
    if leave.status != LeaveStatus.PENDING:
        raise HTTPException(409, "Leave has already been reviewed")
    employee = db.get(Employee, leave.employee_id)
    if employee.user_id == user.id:
        raise HTTPException(403, "Another manager must review your leave")
    leave.status = LeaveStatus.APPROVED if decision == "approved" else LeaveStatus.REJECTED
    leave.reviewed_by = user.id
    leave.reviewed_at = datetime.utcnow()
    db.commit()
    db.refresh(leave)
    return leave


class PayrollCreate(BaseModel):
    employee_id: int
    period: str = Field(pattern=r"^\d{4}-(0[1-9]|1[0-2])$")
    basic_salary: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    overtime: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    allowances: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    deductions: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    advances: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    payment_status: Literal["pending"] = "pending"
    notes: str | None = None

    @model_validator(mode="after")
    def validate_net(self):
        if self.basic_salary + self.overtime + self.allowances < self.deductions + self.advances:
            raise ValueError("Deductions and advances cannot exceed gross pay")
        return self


class PayrollPayment(BaseModel):
    reference: str = Field(min_length=1, max_length=160)


@router.post("/payroll/{record_id}/pay")
def pay_payroll(record_id: int, payload: PayrollPayment, db: Session = Depends(get_db),
                actor: User = Depends(require_roles(UserRole.OWNER, UserRole.ACCOUNTANT))):
    record = db.get(PayrollRecord, record_id, with_for_update=True)
    if not record:
        raise HTTPException(404, "Payroll record not found")
    if record.payment_status != "pending":
        raise HTTPException(409, "Payroll has already been paid")
    record.payment_status = "paid"
    record.paid_at = datetime.utcnow()
    record.notes = (record.notes or "") + f"\nPayment reference: {payload.reference.strip()} (recorded by {actor.id})"
    db.commit()
    db.refresh(record)
    return record


@router.post("/payroll")
def create_payroll(payload: PayrollCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.ACCOUNTANT))):
    if not db.get(Employee, payload.employee_id):
        raise HTTPException(status_code=404, detail="Employee not found")
    existing = db.query(PayrollRecord).filter(PayrollRecord.employee_id == payload.employee_id, PayrollRecord.period == payload.period).first()
    if existing:
        raise HTTPException(status_code=409, detail="Payroll already exists for this employee and period")
    net_salary = payload.basic_salary + payload.overtime + payload.allowances - payload.deductions - payload.advances
    record = PayrollRecord(**payload.model_dump(), net_salary=net_salary)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("/payroll/me")
def my_payroll(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    employee = db.query(Employee).filter(Employee.user_id == user.id).first()
    if not employee:
        return []
    return db.query(PayrollRecord).filter(PayrollRecord.employee_id == employee.id).order_by(PayrollRecord.period.desc()).all()


@router.get("/payroll")
def payroll(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.ACCOUNTANT))):
    return db.query(PayrollRecord).order_by(PayrollRecord.period.desc()).all()
