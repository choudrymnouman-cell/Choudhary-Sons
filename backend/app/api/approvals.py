from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_roles
from app.models.commercial import PurchaseOrder
from app.models.core import Project, ProjectStatus, User, UserRole
from app.models.ownership import ApprovalRequest, ApprovalSettings
from app.models.trade import SupplierPayment

router = APIRouter(prefix="/owner", tags=["owner"])
require_owner = require_roles(UserRole.OWNER)


class Thresholds(BaseModel):
    purchase_order_threshold: Decimal | None = Field(default=None, gt=0, max_digits=16, decimal_places=2)
    vendor_payment_threshold: Decimal | None = Field(default=None, gt=0, max_digits=16, decimal_places=2)


def required_by_limit(db: Session, kind: Literal["purchase_order", "vendor_payment"], amount: Decimal):
    settings = db.get(ApprovalSettings, 1)
    threshold = None
    if settings:
        threshold = settings.purchase_order_threshold if kind == "purchase_order" else settings.vendor_payment_threshold
    return threshold is not None and amount >= threshold


def queue_request(db: Session, *, kind, user_id, description, record_id=None, amount=None, payload=None):
    entry = ApprovalRequest(
        kind=kind, requested_by=user_id, description=description, record_id=record_id, amount=amount, payload=payload
    )
    db.add(entry)
    db.flush()
    return entry


@router.get("/approval-settings")
def get_thresholds(db: Session = Depends(get_db), _: User = Depends(require_owner)):
    settings = db.get(ApprovalSettings, 1)
    return Thresholds(
        purchase_order_threshold=settings.purchase_order_threshold,
        vendor_payment_threshold=settings.vendor_payment_threshold,
    ) if settings else Thresholds()


@router.put("/approval-settings")
def save_thresholds(payload: Thresholds, db: Session = Depends(get_db), _: User = Depends(require_owner)):
    settings = db.scalar(select(ApprovalSettings).where(ApprovalSettings.id == 1).with_for_update())
    if settings is None:
        db.add(ApprovalSettings(id=1, **payload.model_dump()))
    else:
        for key, value in payload.model_dump().items():
            setattr(settings, key, value)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Approval settings changed. Refresh and retry.") from exc
    return payload


@router.get("/approvals")
def approvals(
    state: Literal["pending", "approved", "rejected"] = "pending",
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    _: User = Depends(require_owner),
):
    query = (
        select(ApprovalRequest, User.full_name)
        .join(User, User.id == ApprovalRequest.requested_by)
        .where(ApprovalRequest.status == state)
        .order_by(ApprovalRequest.id.desc())
        .limit(limit)
    )
    return [
        {
            "id": row.id, "kind": row.kind, "description": row.description,
            "amount": row.amount, "status": row.status, "requested_by": name,
            "requested_at": row.requested_at, "record_id": row.record_id,
        }
        for row, name in db.execute(query)
    ]


@router.post("/approvals/{approval_id}/{decision}")
def decide(approval_id: int, decision: Literal["approve", "reject"], db: Session = Depends(get_db),
           user: User = Depends(require_owner)):
    request = db.scalar(select(ApprovalRequest).where(ApprovalRequest.id == approval_id).with_for_update())
    if request is None:
        raise HTTPException(404, "Approval request not found")
    status = "approved" if decision == "approve" else "rejected"
    if request.status == status:
        return {"id": request.id, "status": request.status}
    if request.status != "pending":
        raise HTTPException(409, "This request was already decided")
    if request.kind == "purchase_order":
        order = db.get(PurchaseOrder, request.record_id, with_for_update=True)
        if order is None or order.status != "pending_approval":
            raise HTTPException(409, "Purchase order is no longer pending approval")
        order.status = status
    elif request.kind == "project_signoff" and status == "approved":
        project = db.get(Project, request.record_id, with_for_update=True)
        if project is None or project.status in (ProjectStatus.CANCELLED, ProjectStatus.COMPLETED):
            raise HTTPException(409, "Project is no longer eligible for sign-off")
        project.status = ProjectStatus.COMPLETED
    elif request.kind == "vendor_payment" and status == "approved":
        data = dict(request.payload)
        if data["purchase_order_id"] is not None:
            order = db.get(PurchaseOrder, data["purchase_order_id"], with_for_update=True)
            if order is None or order.status in {"pending_approval", "rejected", "cancelled"}:
                raise HTTPException(409, "Purchase order is not eligible for payment")
        data["payment_date"] = date.fromisoformat(data["payment_date"])
        data["amount"] = request.amount
        payment = SupplierPayment(**data, created_by=request.requested_by)
        db.add(payment)
        db.flush()
        request.record_id = payment.id
    request.status = status
    request.decided_by = user.id
    request.decided_at = datetime.now(timezone.utc)
    db.commit()
    return {"id": request.id, "status": request.status}
