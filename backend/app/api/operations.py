from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.core import Employee, Project, User, UserRole
from app.models.operations import ApplicationStatus, JobApplication, JobVacancy, LeaveRequest, LeaveStatus, PayrollRecord

router = APIRouter(tags=["operations"])


class ProjectCreate(BaseModel):
    code: str
    name: str
    description: str | None = None
    site_address: str | None = None
    contract_value: float = 0


@router.get("/projects")
def list_projects(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(Project).order_by(Project.id.desc()).all()


@router.post("/projects")
def create_project(payload: ProjectCreate, db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.PROJECT_MANAGER))):
    if db.query(Project).filter(Project.code == payload.code).first():
        raise HTTPException(status_code=409, detail="Project code already exists")
    project = Project(**payload.model_dump())
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


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
    leave = LeaveRequest(employee_id=employee.id, leave_type=payload.leave_type, start_date=payload.start_date, end_date=payload.end_date, reason=payload.reason)
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
    leave = db.get(LeaveRequest, leave_id)
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")
    if decision not in {"approved", "rejected"}:
        raise HTTPException(status_code=400, detail="Decision must be approved or rejected")
    leave.status = LeaveStatus.APPROVED if decision == "approved" else LeaveStatus.REJECTED
    leave.reviewed_by = user.id
    leave.reviewed_at = datetime.utcnow()
    db.commit()
    db.refresh(leave)
    return leave


@router.get("/payroll/me")
def my_payroll(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    employee = db.query(Employee).filter(Employee.user_id == user.id).first()
    if not employee:
        return []
    return db.query(PayrollRecord).filter(PayrollRecord.employee_id == employee.id).order_by(PayrollRecord.period.desc()).all()


@router.get("/payroll")
def payroll(db: Session = Depends(get_db), _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.ACCOUNTANT))):
    return db.query(PayrollRecord).order_by(PayrollRecord.period.desc()).all()
