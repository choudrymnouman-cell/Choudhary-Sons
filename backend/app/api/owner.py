from datetime import date, timedelta
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, select, delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_roles
from app.core.security import hash_password
from app.models.commercial import ClientInvoice, Expense
from app.models.core import Project, User, UserRole, UserProjectAssignment
from app.models.ownership import ActivityEvent
from app.models.trade import InvoiceReceipt, SupplierPayment

router = APIRouter(prefix="/owner", tags=["owner"])
require_owner = require_roles(UserRole.OWNER)
StaffRole = Literal["owner", "admin", "hr", "accountant", "project_manager", "site_supervisor", "employee", "pending", "applicant", "procurement", "store", "estimator", "equipment"]


class AccountCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=150)
    email: EmailStr
    role: StaffRole = "employee"
    password: str = Field(min_length=12, max_length=72)
    project_ids: list[int] = Field(default_factory=list, max_length=500)


class AccountUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    role: StaffRole | None = None
    is_active: bool | None = None
    project_ids: list[int] | None = Field(default=None, max_length=500)
    password: str | None = Field(default=None, min_length=12, max_length=72)


def password_digest(value: str) -> str:
    if len(value.encode()) > 72:
        raise HTTPException(422, "Password must fit within 72 UTF-8 bytes")
    return hash_password(value)


def account_public(user: User, db: Session) -> dict:
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "role": user.role.value,
        "is_active": user.is_active,
        "project_ids": list(db.scalars(select(UserProjectAssignment.project_id).where(UserProjectAssignment.user_id == user.id))),
    }


def assign_projects(db: Session, account_id: int, project_ids: list[int]):
    unique = set(project_ids)
    existing = set(db.scalars(select(Project.id).where(Project.id.in_(unique))))
    if existing != unique:
        raise HTTPException(422, "One or more projects no longer exist")
    db.execute(delete(UserProjectAssignment).where(UserProjectAssignment.user_id == account_id))
    db.add_all(UserProjectAssignment(user_id=account_id, project_id=pid) for pid in sorted(unique))


@router.get("/accounts")
def accounts(db: Session = Depends(get_db), _: User = Depends(require_owner)):
    return [account_public(row, db) for row in db.scalars(select(User).order_by(User.id))]


@router.post("/accounts", status_code=201)
def create_account(payload: AccountCreate, db: Session = Depends(get_db), _: User = Depends(require_owner)):
    name = payload.full_name.strip()
    if not name:
        raise HTTPException(422, "Provide a full name")
    email = payload.email.lower()
    if db.scalar(select(User.id).where(func.lower(User.email) == email)) is not None:
        raise HTTPException(409, "Email already exists")
    account = User(full_name=name, email=email, role=UserRole(payload.role), password_hash=password_digest(payload.password))
    db.add(account)
    db.flush()
    assign_projects(db, account.id, payload.project_ids)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Email already exists") from exc
    db.refresh(account)
    return account_public(account, db)


@router.patch("/accounts/{account_id}")
def update_account(
    account_id: int,
    payload: AccountUpdate,
    db: Session = Depends(get_db),
    actor: User = Depends(require_owner),
):
    # Lock owner rows in a predictable order before changing who has owner access.
    owners = db.scalars(select(User).where(User.role == UserRole.OWNER).order_by(User.id).with_for_update()).all()
    if not any(owner.id == actor.id and owner.is_active for owner in owners):
        raise HTTPException(403, "Owner access required")
    account = db.scalar(select(User).where(User.id == account_id).with_for_update())
    if account is None:
        raise HTTPException(404, "Account not found")
    if account.id == actor.id and (payload.is_active is False or payload.role not in (None, "owner")):
        raise HTTPException(409, "You cannot revoke your own owner access")
    if payload.full_name is not None:
        name = payload.full_name.strip()
        if not name:
            raise HTTPException(422, "Provide a full name")
        account.full_name = name
    revoke = False
    if payload.role is not None and payload.role != account.role.value:
        account.role = UserRole(payload.role)
        revoke = True
    if payload.is_active is not None and payload.is_active != account.is_active:
        account.is_active = payload.is_active
        revoke = True
    if payload.password is not None:
        account.password_hash = password_digest(payload.password)
        revoke = True
    if payload.project_ids is not None:
        assign_projects(db, account.id, payload.project_ids)
        revoke = True
    if revoke:
        account.token_version += 1
    db.commit()
    db.refresh(account)
    return account_public(account, db)


@router.get("/activity")
def activity(
    before_id: int | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    _: User = Depends(require_owner),
):
    query = select(ActivityEvent, User.full_name).outerjoin(User, User.id == ActivityEvent.actor_id)
    if before_id is not None:
        query = query.where(ActivityEvent.id < before_id)
    return [
        {
            "id": event.id, "actor_id": event.actor_id, "actor": name,
            "method": event.method, "resource": event.resource, "resource_id": event.resource_id,
            "status_code": event.status_code, "occurred_at": event.occurred_at,
        }
        for event, name in db.execute(query.order_by(ActivityEvent.id.desc()).limit(limit))
    ]


@router.get("/overview")
def overview(
    days: int = Query(default=30, ge=7, le=365),
    db: Session = Depends(get_db),
    _: User = Depends(require_owner),
):
    end = date.today()
    start = end - timedelta(days=days - 1)

    def sum_amount(column, condition=None):
        query = select(func.coalesce(func.sum(column), 0))
        if condition is not None:
            query = query.where(condition)
        return Decimal(str(db.scalar(query)))

    # Existing expense and supplier-payment records may describe the same cost.
    # Keep them separate, and count only the expense ledger in the margin.
    invoiced = sum_amount(ClientInvoice.total_amount, ClientInvoice.invoice_date.between(start, end))
    expenses = sum_amount(Expense.amount, Expense.expense_date.between(start, end))
    receivables = sum_amount(ClientInvoice.total_amount - ClientInvoice.paid_amount)
    receipts = db.execute(
        select(func.date(InvoiceReceipt.created_at), func.sum(InvoiceReceipt.amount))
        .group_by(func.date(InvoiceReceipt.created_at))
        .where(func.date(InvoiceReceipt.created_at).between(start, end))
    )
    payments = db.execute(
        select(SupplierPayment.payment_date, func.sum(SupplierPayment.amount))
        .group_by(SupplierPayment.payment_date)
        .where(SupplierPayment.payment_date.between(start, end))
    )
    incoming = {str(day): amount for day, amount in receipts}
    outgoing = {str(day): amount for day, amount in payments}
    flow = [
        {"date": day, "receipts": incoming.get(day, 0), "supplier_payments": outgoing.get(day, 0)}
        for day in ((start + timedelta(days=offset)).isoformat() for offset in range(days))
    ]
    return {
        "start_date": start, "end_date": end,
        "billed": invoiced, "recorded_expenses": expenses, "billed_less_expenses": invoiced - expenses,
        "open_receivables": receivables,
        "project_count": db.scalar(select(func.count()).select_from(Project)),
        "cash_movements": flow,
    }
