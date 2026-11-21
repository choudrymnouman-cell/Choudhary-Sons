from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator
from decimal import Decimal
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_roles
from app.core.security import hash_password
from app.models.core import Employee, Project, User, UserRole

router = APIRouter(prefix="/employees", tags=["employees"])


class EmployeeCreate(BaseModel):
    full_name: str
    email: EmailStr
    phone: str | None = None
    password: str = Field(min_length=12)
    employee_code: str
    designation: str
    department: str | None = None
    joining_date: date
    basic_salary: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    project_id: int | None = None
    cnic: str | None = None
    emergency_contact: str | None = None
    address: str | None = None
    role: UserRole = UserRole.EMPLOYEE


class EmployeeUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    designation: str | None = None
    department: str | None = None
    basic_salary: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    project_id: int | None = None
    cnic: str | None = None
    emergency_contact: str | None = None
    address: str | None = None
    role: UserRole | None = None

    @model_validator(mode="after")
    def non_nullable_fields(self):
        for key in ("full_name", "designation", "basic_salary"):
            if key in self.model_fields_set and (getattr(self, key) is None or getattr(self, key) == ""):
                raise ValueError(f"{key} cannot be blank")
        return self


class EmployeeLink(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    user_id: int
    employee_code: str = Field(min_length=1, max_length=30)
    designation: str = Field(min_length=1, max_length=120)
    department: str | None = Field(default=None, max_length=120)
    joining_date: date
    basic_salary: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    project_id: int | None = None


def check_project(db, project_id):
    if project_id is not None and not db.get(Project, project_id):
        raise HTTPException(404, "Project not found")


@router.get("/unlinked-accounts")
def unlinked_accounts(db: Session = Depends(get_db),
                      _: User = Depends(require_roles(UserRole.OWNER, UserRole.HR, UserRole.ADMIN))):
    users = db.scalars(select(User).where(User.is_active.is_(True),
        User.role.notin_([UserRole.PENDING, UserRole.APPLICANT, UserRole.OWNER]),
        ~User.employee.has()).order_by(User.full_name)).all()
    return [{"id": u.id, "full_name": u.full_name, "email": u.email, "role": u.role.value} for u in users]


@router.post("/link-account", status_code=201)
def link_account(payload: EmployeeLink, db: Session = Depends(get_db),
                 _: User = Depends(require_roles(UserRole.OWNER, UserRole.HR, UserRole.ADMIN))):
    user = db.get(User, payload.user_id, with_for_update=True)
    if not user or not user.is_active or user.role in {UserRole.PENDING, UserRole.APPLICANT, UserRole.OWNER}:
        raise HTTPException(400, "Select an active staff account approved by the owner")
    if user.employee:
        raise HTTPException(409, "This account already has an employee profile")
    check_project(db, payload.project_id)
    employee = Employee(**payload.model_dump())
    db.add(employee)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Employee code or account already linked")
    db.refresh(employee)
    return {"id": employee.id, "message": "Staff profile linked; login and permissions unchanged"}


@router.get("")
def list_employees(
    db: Session = Depends(get_db),
    actor: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.ACCOUNTANT)),
):
    employees = db.scalars(select(Employee).order_by(Employee.id.desc())).all()
    return [
        {
            "id": e.id,
            "project_id": e.project_id,
            **({"cnic": e.cnic, "address": e.address, "emergency_contact": e.emergency_contact}
               if actor.role != UserRole.ACCOUNTANT else {}),
            "employee_code": e.employee_code,
            "full_name": e.user.full_name,
            "email": e.user.email,
            "phone": e.user.phone,
            "designation": e.designation,
            "department": e.department,
            "joining_date": e.joining_date,
            "basic_salary": float(e.basic_salary),
            "role": e.user.role.value,
            "is_active": e.user.is_active,
        }
        for e in employees
    ]


@router.post("", status_code=201)
def create_employee(
    payload: EmployeeCreate,
    db: Session = Depends(get_db),
    actor: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR)),
):
    if payload.role != UserRole.EMPLOYEE and actor.role != UserRole.OWNER:
        raise HTTPException(403, "Only an owner can grant staff permissions")
    if db.scalar(select(User).where(User.email == payload.email)):
        raise HTTPException(status_code=409, detail="Email already exists")
    if db.scalar(select(Employee).where(Employee.employee_code == payload.employee_code)):
        raise HTTPException(status_code=409, detail="Employee code already exists")

    check_project(db, payload.project_id)
    user = User(
        full_name=payload.full_name,
        email=payload.email,
        phone=payload.phone,
        password_hash=hash_password(payload.password),
        role=payload.role if actor.role == UserRole.OWNER else UserRole.PENDING,
    )
    db.add(user)
    db.flush()

    employee = Employee(
        user_id=user.id,
        project_id=payload.project_id,
        employee_code=payload.employee_code,
        designation=payload.designation,
        department=payload.department,
        joining_date=payload.joining_date,
        basic_salary=payload.basic_salary,
        cnic=payload.cnic,
        emergency_contact=payload.emergency_contact,
        address=payload.address,
    )
    db.add(employee)
    db.commit()
    db.refresh(employee)
    return {"id": employee.id, "employee_code": employee.employee_code, "message": "Employee created"}


@router.patch("/{employee_id}")
def update_employee(
    employee_id: int,
    payload: EmployeeUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR)),
):
    employee = db.get(Employee, employee_id)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    if employee.user.role == UserRole.OWNER or payload.role is not None:
        raise HTTPException(403, "Use the owner console to manage account access")
    data = payload.model_dump(exclude_unset=True, exclude={"role"})
    if "project_id" in data:
        check_project(db, data["project_id"])
    for key in ("full_name", "phone", "role"):
        if key in data:
            setattr(employee.user, key, data.pop(key))
    for key, value in data.items():
        setattr(employee, key, value)
    db.commit()
    db.refresh(employee)
    return {"id": employee.id, "employee_code": employee.employee_code, "message": "Employee updated"}


@router.patch("/{employee_id}/deactivate")
def deactivate_employee(
    employee_id: int,
    db: Session = Depends(get_db),
    actor: User = Depends(require_roles(UserRole.OWNER)),
):
    employee = db.get(Employee, employee_id)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    if employee.user.role == UserRole.OWNER or (
        employee.user.role != UserRole.EMPLOYEE and actor.role != UserRole.OWNER
    ):
        raise HTTPException(403, "Use the owner console to manage account access")
    employee.user.is_active = False
    employee.user.token_version += 1
    db.commit()
    return {"id": employee.id, "message": "Employee deactivated"}


@router.get("/me")
def my_employee_profile(current_user: User = Depends(get_current_user)):
    if not current_user.employee:
        raise HTTPException(status_code=404, detail="Employee profile not found")
    e = current_user.employee
    return {
        "id": e.id,
        "employee_code": e.employee_code,
        "full_name": current_user.full_name,
        "email": current_user.email,
        "phone": current_user.phone,
        "designation": e.designation,
        "department": e.department,
        "joining_date": e.joining_date,
        "basic_salary": float(e.basic_salary),
        "cnic": e.cnic,
        "emergency_contact": e.emergency_contact,
        "address": e.address,
    }
