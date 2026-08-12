import enum
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class Supplier(Base):
    __tablename__ = "suppliers"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(180), index=True)
    contact_person: Mapped[str | None] = mapped_column(String(150), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    tax_number: Mapped[str | None] = mapped_column(String(60), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    rating: Mapped[float | None] = mapped_column(Numeric(3, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Material(Base):
    __tablename__ = "materials"

    id: Mapped[int] = mapped_column(primary_key=True)
    sku: Mapped[str] = mapped_column(String(60), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(180), index=True)
    unit: Mapped[str] = mapped_column(String(30), default="unit")
    quantity_on_hand: Mapped[float] = mapped_column(Numeric(14, 3), default=0)
    reorder_level: Mapped[float] = mapped_column(Numeric(14, 3), default=0)
    average_cost: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    location: Mapped[str | None] = mapped_column(String(180), nullable=True)


class PurchaseOrder(Base):
    __tablename__ = "purchase_orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    po_number: Mapped[str] = mapped_column(String(60), unique=True, index=True)
    supplier_id: Mapped[int] = mapped_column(ForeignKey("suppliers.id"), index=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    order_date: Mapped[date] = mapped_column(Date, default=date.today)
    expected_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(30), default="draft")
    subtotal: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    tax_amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    total_amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class PurchaseOrderItem(Base):
    __tablename__ = "purchase_order_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    purchase_order_id: Mapped[int] = mapped_column(ForeignKey("purchase_orders.id"), index=True)
    material_id: Mapped[int | None] = mapped_column(ForeignKey("materials.id"), nullable=True)
    description: Mapped[str] = mapped_column(String(220))
    quantity: Mapped[float] = mapped_column(Numeric(14, 3), default=0)
    unit: Mapped[str] = mapped_column(String(30), default="unit")
    unit_price: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    line_total: Mapped[float] = mapped_column(Numeric(16, 2), default=0)


class BoqItem(Base):
    __tablename__ = "boq_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id"), index=True)
    item_code: Mapped[str | None] = mapped_column(String(60), nullable=True)
    description: Mapped[str] = mapped_column(Text)
    unit: Mapped[str] = mapped_column(String(30))
    quantity: Mapped[float] = mapped_column(Numeric(14, 3), default=0)
    unit_rate: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    completed_quantity: Mapped[float] = mapped_column(Numeric(14, 3), default=0)


class Expense(Base):
    __tablename__ = "expenses"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    category: Mapped[str] = mapped_column(String(80), index=True)
    description: Mapped[str] = mapped_column(String(255))
    amount: Mapped[float] = mapped_column(Numeric(16, 2))
    expense_date: Mapped[date] = mapped_column(Date, default=date.today)
    vendor: Mapped[str | None] = mapped_column(String(180), nullable=True)
    payment_method: Mapped[str | None] = mapped_column(String(50), nullable=True)
    reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ClientInvoice(Base):
    __tablename__ = "client_invoices"

    id: Mapped[int] = mapped_column(primary_key=True)
    invoice_number: Mapped[str] = mapped_column(String(60), unique=True, index=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id"), index=True)
    client_id: Mapped[int | None] = mapped_column(ForeignKey("clients.id"), nullable=True)
    invoice_date: Mapped[date] = mapped_column(Date, default=date.today)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    tax_amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    total_amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    paid_amount: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    status: Mapped[str] = mapped_column(String(30), default="unpaid")
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
