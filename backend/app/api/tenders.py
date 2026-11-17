from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Literal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_roles
from app.models.core import User, UserRole
from app.models.tender import Tender

router = APIRouter(prefix="/owner/tenders", tags=["tenders"])
require_owner = require_roles(UserRole.OWNER)
TenderStatus = Literal["upcoming", "submitted", "won", "lost", "withdrawn"]


class TenderInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    reference: str = Field(min_length=1, max_length=70)
    title: str = Field(min_length=1, max_length=180)
    authority: str = Field(min_length=1, max_length=180)
    deadline: date
    status: TenderStatus = "upcoming"
    bid_amount: Decimal | None = Field(default=None, gt=0, max_digits=16, decimal_places=2)
    estimated_cost: Decimal | None = Field(default=None, ge=0, max_digits=16, decimal_places=2)
    notes: str | None = Field(default=None, max_length=4000)


def tender_view(tender: Tender, today: date) -> dict:
    margin = None
    profit = None
    if tender.bid_amount is not None and tender.estimated_cost is not None:
        profit = tender.bid_amount - tender.estimated_cost
        margin = round(profit * 100 / tender.bid_amount, 2)
    return {
        "id": tender.id, "reference": tender.reference, "title": tender.title,
        "authority": tender.authority, "status": tender.status, "deadline": tender.deadline,
        "days_until_deadline": (tender.deadline - today).days,
        "bid_amount": tender.bid_amount, "estimated_cost": tender.estimated_cost,
        "estimated_profit": profit, "estimated_margin_percent": margin, "notes": tender.notes,
    }


def today_in_pakistan() -> date:
    return datetime.now(ZoneInfo("Asia/Karachi")).date()


@router.get("")
def list_tenders(status: TenderStatus | None = None, db: Session = Depends(get_db), _: User = Depends(require_owner)):
    query = select(Tender).order_by(Tender.deadline, Tender.id)
    if status is not None:
        query = query.where(Tender.status == status)
    today = today_in_pakistan()
    return [tender_view(row, today) for row in db.scalars(query)]


def save_tender(db: Session, tender: Tender, values: TenderInput, actor: User) -> dict:
    data = values.model_dump()
    data["reference"] = values.reference.upper()
    for key, value in data.items():
        setattr(tender, key, value)
    tender.updated_by = actor.id
    tender.updated_at = datetime.now(timezone.utc)
    db.add(tender)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Tender reference already exists") from exc
    return tender_view(tender, today_in_pakistan())


@router.post("", status_code=201)
def create_tender(payload: TenderInput, db: Session = Depends(get_db), actor: User = Depends(require_owner)):
    return save_tender(db, Tender(), payload, actor)


@router.put("/{tender_id}")
def update_tender(tender_id: int, payload: TenderInput, db: Session = Depends(get_db),
                  actor: User = Depends(require_owner)):
    row = db.get(Tender, tender_id, with_for_update=True)
    if row is None:
        raise HTTPException(404, "Tender not found")
    return save_tender(db, row, payload, actor)
