from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class Tender(Base):
    __tablename__ = "tenders"

    id: Mapped[int] = mapped_column(primary_key=True)
    reference: Mapped[str] = mapped_column(String(70), unique=True)
    title: Mapped[str] = mapped_column(String(180))
    authority: Mapped[str] = mapped_column(String(180))
    deadline: Mapped[date] = mapped_column(index=True)
    status: Mapped[str] = mapped_column(String(20), default="upcoming")
    bid_amount: Mapped[Decimal | None] = mapped_column(Numeric(16, 2))
    estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(16, 2))
    notes: Mapped[str | None] = mapped_column(Text)
    updated_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
