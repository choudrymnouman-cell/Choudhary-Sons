from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.commercial import require_management
from app.db.session import get_db
from app.models.commercial import ClientInvoice, Material, PurchaseOrder, Supplier
from app.models.core import Client, Project, User
from app.models.trade import InvoiceReceipt, PurchaseDelivery, StockMovement, SupplierPayment

router = APIRouter(prefix="/commercial", tags=["commercial"])


class StockQuantity(BaseModel):
    material_id: int
    quantity: Decimal = Field(gt=0, max_digits=14, decimal_places=3)
    unit_cost: Decimal | None = Field(default=None, ge=0, max_digits=14, decimal_places=2)


class StockMovementInput(StockQuantity):
    project_id: int | None = None
    movement_type: Literal["received", "issued", "adjustment_in", "adjustment_out"]
    reference: str | None = Field(default=None, max_length=120)
    notes: str | None = None


class DeliveryInput(StockQuantity):
    purchase_order_id: int
    delivery_date: date = Field(default_factory=date.today)
    challan_number: str | None = Field(default=None, max_length=120)


class AmountInput(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=16, decimal_places=2)


class PaymentInput(AmountInput):
    supplier_id: int
    purchase_order_id: int | None = None
    payment_date: date = Field(default_factory=date.today)
    payment_method: str | None = Field(default=None, max_length=50)
    reference: str | None = Field(default=None, max_length=120)


class ClientInput(BaseModel):
    name: str = Field(min_length=1, max_length=180)


def record_stock(db: Session, payload: StockMovementInput, user: User) -> StockMovement:
    material = db.scalar(select(Material).where(Material.id == payload.material_id).with_for_update())
    if material is None:
        raise HTTPException(404, "Material not found")
    if payload.project_id is not None and db.get(Project, payload.project_id) is None:
        raise HTTPException(404, "Project not found")

    current = material.quantity_on_hand
    incoming = payload.movement_type in ("received", "adjustment_in")
    updated = current + payload.quantity if incoming else current - payload.quantity
    if updated < 0:
        raise HTTPException(409, "Insufficient stock")
    if updated >= Decimal("100000000000"):
        raise HTTPException(422, "Stock exceeds the supported quantity")

    cost = payload.unit_cost if incoming and payload.unit_cost is not None else material.average_cost
    if incoming:
        value = current * material.average_cost + payload.quantity * cost
        material.average_cost = (value / updated).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    material.quantity_on_hand = updated

    movement = StockMovement(**payload.model_dump(exclude={"unit_cost"}), unit_cost=cost, created_by=user.id)
    db.add(movement)
    db.flush()
    return movement


@router.get("/stock-movements")
def stock_movements(db: Session = Depends(get_db), _: User = Depends(require_management)):
    query = (
        select(StockMovement, Material.name, Material.unit, Project.name, Project.code)
        .join(Material, Material.id == StockMovement.material_id)
        .outerjoin(Project, Project.id == StockMovement.project_id)
        .order_by(StockMovement.id.desc())
        .limit(100)
    )
    return [
        {**vars(row), "materials": {"name": name, "unit": unit},
         "projects": {"name": project, "code": code} if project else None}
        for row, name, unit, project, code in db.execute(query)
    ]


@router.post("/stock-movements", status_code=201)
def create_stock_movement(payload: StockMovementInput, db: Session = Depends(get_db), user: User = Depends(require_management)):
    movement = record_stock(db, payload, user)
    db.commit()
    db.refresh(movement)
    return movement


@router.get("/deliveries")
def deliveries(db: Session = Depends(get_db), _: User = Depends(require_management)):
    query = (
        select(PurchaseDelivery, PurchaseOrder.po_number, Material.name, Material.unit)
        .join(PurchaseOrder, PurchaseOrder.id == PurchaseDelivery.purchase_order_id)
        .join(Material, Material.id == PurchaseDelivery.material_id)
        .order_by(PurchaseDelivery.id.desc())
        .limit(100)
    )
    return [
        {**vars(row), "purchase_orders": {"po_number": order}, "materials": {"name": name, "unit": unit}}
        for row, order, name, unit in db.execute(query)
    ]


@router.post("/deliveries", status_code=201)
def create_delivery(payload: DeliveryInput, db: Session = Depends(get_db), user: User = Depends(require_management)):
    order = db.get(PurchaseOrder, payload.purchase_order_id)
    if order is None:
        raise HTTPException(404, "Purchase order not found")
    if order.status == "cancelled":
        raise HTTPException(409, "Purchase order is cancelled")
    movement = record_stock(
        db,
        StockMovementInput(
            **payload.model_dump(include={"material_id", "quantity", "unit_cost"}),
            project_id=order.project_id,
            movement_type="received",
            reference=payload.challan_number,
        ),
        user,
    )
    delivery = PurchaseDelivery(**payload.model_dump(exclude={"unit_cost"}), stock_movement_id=movement.id)
    db.add(delivery)
    db.commit()
    db.refresh(delivery)
    return delivery


@router.get("/supplier-payments")
def supplier_payments(db: Session = Depends(get_db), _: User = Depends(require_management)):
    query = (
        select(SupplierPayment, Supplier.name, PurchaseOrder.po_number)
        .join(Supplier, Supplier.id == SupplierPayment.supplier_id)
        .outerjoin(PurchaseOrder, PurchaseOrder.id == SupplierPayment.purchase_order_id)
        .order_by(SupplierPayment.id.desc())
    )
    return [
        {**vars(row), "suppliers": {"name": name}, "purchase_orders": {"po_number": order} if order else None}
        for row, name, order in db.execute(query)
    ]


@router.post("/supplier-payments", status_code=201)
def create_supplier_payment(payload: PaymentInput, db: Session = Depends(get_db), user: User = Depends(require_management)):
    if db.get(Supplier, payload.supplier_id) is None:
        raise HTTPException(404, "Supplier not found")
    if payload.purchase_order_id is not None:
        order = db.get(PurchaseOrder, payload.purchase_order_id)
        if order is None:
            raise HTTPException(404, "Purchase order not found")
        if order.supplier_id != payload.supplier_id:
            raise HTTPException(422, "Purchase order belongs to a different supplier")
    payment = SupplierPayment(**payload.model_dump(), created_by=user.id)
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return payment


@router.get("/clients")
def clients(db: Session = Depends(get_db), _: User = Depends(require_management)):
    return db.scalars(select(Client).order_by(Client.name, Client.id)).all()


@router.post("/clients", status_code=201)
def create_client(payload: ClientInput, db: Session = Depends(get_db), _: User = Depends(require_management)):
    name = payload.name.strip()
    if not name:
        raise HTTPException(422, "Client name is required")
    client = Client(name=name)
    db.add(client)
    db.commit()
    db.refresh(client)
    return client


@router.get("/receivables")
def receivables(db: Session = Depends(get_db), _: User = Depends(require_management)):
    query = (
        select(ClientInvoice, Client.name, Project.name, Project.code)
        .join(Project, Project.id == ClientInvoice.project_id)
        .outerjoin(Client, Client.id == ClientInvoice.client_id)
        .order_by(ClientInvoice.invoice_date.desc(), ClientInvoice.id.desc())
    )
    return [
        {**vars(row), "clients": {"name": name} if name else None,
         "projects": {"name": project, "code": code}}
        for row, name, project, code in db.execute(query)
    ]


@router.post("/invoices/{invoice_id}/receipts", status_code=201)
def receive_invoice(invoice_id: int, payload: AmountInput, db: Session = Depends(get_db), user: User = Depends(require_management)):
    invoice = db.scalar(select(ClientInvoice).where(ClientInvoice.id == invoice_id).with_for_update())
    if invoice is None:
        raise HTTPException(404, "Invoice not found")
    updated = invoice.paid_amount + payload.amount
    if updated > invoice.total_amount:
        raise HTTPException(409, "Receipt exceeds the outstanding amount")
    invoice.paid_amount = updated
    invoice.status = "paid" if updated == invoice.total_amount else "partial"
    receipt = InvoiceReceipt(invoice_id=invoice.id, amount=payload.amount, created_by=user.id)
    db.add(receipt)
    db.commit()
    db.refresh(receipt)
    return receipt
