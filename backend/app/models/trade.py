from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def utcnow():
    return datetime.now(timezone.utc)


class StockMovement(Base):
    __tablename__ = "material_stock_movements"

    id: Mapped[int] = mapped_column(primary_key=True)
    material_id: Mapped[int] = mapped_column(ForeignKey("materials.id"), index=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"))
    movement_type: Mapped[str] = mapped_column(String(30))
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    reference: Mapped[str | None] = mapped_column(String(120))
    notes: Mapped[str | None] = mapped_column(Text)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class PurchaseDelivery(Base):
    __tablename__ = "purchase_deliveries"

    id: Mapped[int] = mapped_column(primary_key=True)
    purchase_order_id: Mapped[int] = mapped_column(ForeignKey("purchase_orders.id"), index=True)
    material_id: Mapped[int] = mapped_column(ForeignKey("materials.id"))
    stock_movement_id: Mapped[int] = mapped_column(ForeignKey("material_stock_movements.id"), unique=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3))
    delivery_date: Mapped[date] = mapped_column(Date, default=date.today)
    challan_number: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class SupplierPayment(Base):
    __tablename__ = "supplier_payments"

    id: Mapped[int] = mapped_column(primary_key=True)
    supplier_id: Mapped[int] = mapped_column(ForeignKey("suppliers.id"), index=True)
    purchase_order_id: Mapped[int | None] = mapped_column(ForeignKey("purchase_orders.id"))
    amount: Mapped[Decimal] = mapped_column(Numeric(16, 2))
    payment_date: Mapped[date] = mapped_column(Date, default=date.today)
    payment_method: Mapped[str | None] = mapped_column(String(50))
    reference: Mapped[str | None] = mapped_column(String(120))
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class InvoiceReceipt(Base):
    __tablename__ = "invoice_receipts"

    id: Mapped[int] = mapped_column(primary_key=True)
    invoice_id: Mapped[int] = mapped_column(ForeignKey("client_invoices.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(16, 2))
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
