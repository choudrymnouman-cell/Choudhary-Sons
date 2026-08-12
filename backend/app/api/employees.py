from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_roles
from app.core.security import hash_password
from app.models.core import Employee, User, UserRole

router = APIRouter(prefix="/employees", tags=["employees"])


class EmployeeCreate(BaseModel):
    full_name: str
    email: EmailStr
    phone: str | None = None
    password: str
    employee_code: str
    designation: str
    department: str | None = None
    joining_date: date
    basic_salary: float = 0
    cnic: str | None = None
    emergency_contact: str | None = None
    address: str | None = None
    role: UserRole = UserRole.EMPLOYEE


@router.get("")
def list_employees(
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.ACCOUNTANT, UserRole.PROJECT_MANAGER)),
):
    employees = db.scalars(select(Employee).order_by(Employee.id.desc())).all()
    return [
        {
            "id": e.id,
            "employee_code": e.employee_code,
            "full_name": e.user.full_name,
            "email": e.user.email,
            "phone": e.user.phone,
            "designation": e.designation,
            "department": e.department,
            "joining_date": e.joining_date,
            "basic_salary": float(e.basic_salary),
            "role": e.user.role.value,
        }
        for e in employees
    ]


@router.post("", status_code=201)
def create_employee(
    payload: EmployeeCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR)),
):
    if db.scalar(select(User).where(User.email == payload.email)):
        raise HTTPException(status_code=409, detail="Email already exists")
    if db.scalar(select(Employee).where(Employee.employee_code == payload.employee_code)):
        raise HTTPException(status_code=409, detail="Employee code already exists")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        phone=payload.phone,
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    db.flush()

    employee = Employee(
        user_id=user.id,
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
