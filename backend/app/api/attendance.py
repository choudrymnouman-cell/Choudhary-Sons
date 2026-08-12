from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_roles
from app.models.core import Attendance, Employee, User, UserRole

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.post("/check-in")
def check_in(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    employee = current_user.employee
    if not employee:
        raise HTTPException(status_code=404, detail="Employee profile not found")

    today = date.today()
    record = db.scalar(
        select(Attendance).where(
            and_(Attendance.employee_id == employee.id, Attendance.attendance_date == today)
        )
    )
    if record and record.check_in_at:
        raise HTTPException(status_code=409, detail="Already checked in today")

    if not record:
        record = Attendance(employee_id=employee.id, attendance_date=today, status="present")
        db.add(record)
    record.check_in_at = datetime.utcnow()
    db.commit()
    db.refresh(record)
    return {"message": "Checked in", "check_in_at": record.check_in_at}


@router.post("/check-out")
def check_out(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    employee = current_user.employee
    if not employee:
        raise HTTPException(status_code=404, detail="Employee profile not found")

    today = date.today()
    record = db.scalar(
        select(Attendance).where(
            and_(Attendance.employee_id == employee.id, Attendance.attendance_date == today)
        )
    )
    if not record or not record.check_in_at:
        raise HTTPException(status_code=400, detail="Check in first")
    if record.check_out_at:
        raise HTTPException(status_code=409, detail="Already checked out today")

    record.check_out_at = datetime.utcnow()
    db.commit()
    return {"message": "Checked out", "check_out_at": record.check_out_at}


@router.get("/me")
def my_attendance(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    employee = current_user.employee
    if not employee:
        raise HTTPException(status_code=404, detail="Employee profile not found")
    records = db.scalars(
        select(Attendance)
        .where(Attendance.employee_id == employee.id)
        .order_by(Attendance.attendance_date.desc())
    ).all()
    return [
        {
            "date": r.attendance_date,
            "check_in_at": r.check_in_at,
            "check_out_at": r.check_out_at,
            "status": r.status,
            "notes": r.notes,
        }
        for r in records
    ]


@router.get("")
def attendance_admin(
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN, UserRole.HR, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR)),
):
    rows = db.execute(
        select(Attendance, Employee, User)
        .join(Employee, Attendance.employee_id == Employee.id)
        .join(User, Employee.user_id == User.id)
        .order_by(Attendance.attendance_date.desc())
    ).all()
    return [
        {
            "attendance_id": a.id,
            "employee_id": e.id,
            "employee_code": e.employee_code,
            "full_name": u.full_name,
            "date": a.attendance_date,
            "check_in_at": a.check_in_at,
            "check_out_at": a.check_out_at,
            "status": a.status,
        }
        for a, e, u in rows
    ]
