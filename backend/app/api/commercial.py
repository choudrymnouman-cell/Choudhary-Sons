from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.auth import get_current_user
from app.db.session import get_db
from app.models.commercial import BoqItem, ClientInvoice, Expense, Material, PurchaseOrder, Supplier
from app.models.core import Project, User, UserRole

router = APIRouter(prefix="/commercial", tags=["commercial"])

MANAGEMENT_ROLES = {
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.ACCOUNTANT,
    UserRole.PROJECT_MANAGER,
    UserRole.SITE_SUPERVISOR,
}


def require_management(user: User = Depends(get_current_user)) -> User:
    if user.role not in MANAGEMENT_ROLES:
        raise HTTPException(status_code=403, detail="Management access required")
    return user


class SupplierCreate(BaseModel):
    name: str
    contact_person: str | None = None
    phone: str | None = None
    email: str | None = None
    tax_number: str | None = None
    address: str | None = None


class MaterialCreate(BaseModel):
    sku: str
    name: str
    unit: str = "unit"
    quantity_on_hand: float = 0
    reorder_level: float = 0
    average_cost: float = 0
    location: str | None = None


class PurchaseOrderCreate(BaseModel):
    po_number: str
    supplier_id: int
    project_id: int | None = None
    order_date: date
    expected_date: date | None = None
    subtotal: float = 0
    tax_amount: float = 0
    total_amount: float = 0
    notes: str | None = None


class BoqItemCreate(BaseModel):
    project_id: int
    item_code: str | None = None
    description: str
    unit: str
    quantity: float
    unit_rate: float
    completed_quantity: float = 0


class ExpenseCreate(BaseModel):
    project_id: int | None = None
    category: str
    description: str
    amount: float
    expense_date: date
    vendor: str | None = None
    payment_method: str | None = None
    reference: str | None = None


class InvoiceCreate(BaseModel):
    invoice_number: str
    project_id: int
    client_id: int | None = None
    invoice_date: date
    due_date: date | None = None
    amount: float
    tax_amount: float = 0
    paid_amount: float = 0
    notes: str | None = None


@router.get("/suppliers")
def list_suppliers(db: Session = Depends(get_db), _: User = Depends(require_management)):
    return db.query(Supplier).order_by(Supplier.name).all()


@router.post("/suppliers")
def create_supplier(payload: SupplierCreate, db: Session = Depends(get_db), _: User = Depends(require_management)):
    supplier = Supplier(**payload.model_dump())
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.get("/materials")
def list_materials(db: Session = Depends(get_db), _: User = Depends(require_management)):
    return db.query(Material).order_by(Material.name).all()


@router.post("/materials")
def create_material(payload: MaterialCreate, db: Session = Depends(get_db), _: User = Depends(require_management)):
    if db.query(Material).filter(Material.sku == payload.sku).first():
        raise HTTPException(status_code=400, detail="SKU already exists")
    item = Material(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/materials/low-stock")
def low_stock(db: Session = Depends(get_db), _: User = Depends(require_management)):
    return db.query(Material).filter(Material.quantity_on_hand <= Material.reorder_level).order_by(Material.name).all()


@router.get("/purchase-orders")
def list_purchase_orders(db: Session = Depends(get_db), _: User = Depends(require_management)):
    return db.query(PurchaseOrder).order_by(PurchaseOrder.id.desc()).all()


@router.post("/purchase-orders")
def create_purchase_order(payload: PurchaseOrderCreate, db: Session = Depends(get_db), _: User = Depends(require_management)):
    if db.query(PurchaseOrder).filter(PurchaseOrder.po_number == payload.po_number).first():
        raise HTTPException(status_code=400, detail="PO number already exists")
    po = PurchaseOrder(**payload.model_dump())
    db.add(po)
    db.commit()
    db.refresh(po)
    return po


@router.get("/boq/{project_id}")
def project_boq(project_id: int, db: Session = Depends(get_db), _: User = Depends(require_management)):
    return db.query(BoqItem).filter(BoqItem.project_id == project_id).order_by(BoqItem.id).all()


@router.post("/boq")
def create_boq_item(payload: BoqItemCreate, db: Session = Depends(get_db), _: User = Depends(require_management)):
    if not db.get(Project, payload.project_id):
        raise HTTPException(status_code=404, detail="Project not found")
    data = payload.model_dump()
    data["amount"] = payload.quantity * payload.unit_rate
    item = BoqItem(**data)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/expenses")
def list_expenses(project_id: int | None = None, db: Session = Depends(get_db), _: User = Depends(require_management)):
    query = db.query(Expense)
    if project_id is not None:
        query = query.filter(Expense.project_id == project_id)
    return query.order_by(Expense.expense_date.desc(), Expense.id.desc()).all()


@router.post("/expenses")
def create_expense(payload: ExpenseCreate, db: Session = Depends(get_db), _: User = Depends(require_management)):
    expense = Expense(**payload.model_dump())
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense


@router.get("/invoices")
def list_invoices(project_id: int | None = None, db: Session = Depends(get_db), _: User = Depends(require_management)):
    query = db.query(ClientInvoice)
    if project_id is not None:
        query = query.filter(ClientInvoice.project_id == project_id)
    return query.order_by(ClientInvoice.invoice_date.desc(), ClientInvoice.id.desc()).all()


@router.post("/invoices")
def create_invoice(payload: InvoiceCreate, db: Session = Depends(get_db), _: User = Depends(require_management)):
    if db.query(ClientInvoice).filter(ClientInvoice.invoice_number == payload.invoice_number).first():
        raise HTTPException(status_code=400, detail="Invoice number already exists")
    data = payload.model_dump()
    data["total_amount"] = payload.amount + payload.tax_amount
    data["status"] = "paid" if payload.paid_amount >= data["total_amount"] else ("partial" if payload.paid_amount > 0 else "unpaid")
    invoice = ClientInvoice(**data)
    db.add(invoice)
    db.commit()
    db.refresh(invoice)
    return invoice


@router.get("/projects/{project_id}/profitability")
def project_profitability(project_id: int, db: Session = Depends(get_db), _: User = Depends(require_management)):
    project = db.get(Project, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    expenses = db.query(func.coalesce(func.sum(Expense.amount), 0)).filter(Expense.project_id == project_id).scalar()
    invoiced = db.query(func.coalesce(func.sum(ClientInvoice.total_amount), 0)).filter(ClientInvoice.project_id == project_id).scalar()
    received = db.query(func.coalesce(func.sum(ClientInvoice.paid_amount), 0)).filter(ClientInvoice.project_id == project_id).scalar()
    boq_value = db.query(func.coalesce(func.sum(BoqItem.amount), 0)).filter(BoqItem.project_id == project_id).scalar()

    expenses = float(expenses or 0)
    invoiced = float(invoiced or 0)
    received = float(received or 0)
    boq_value = float(boq_value or 0)
    contract_value = float(project.contract_value or 0)

    return {
        "project_id": project.id,
        "project_name": project.name,
        "contract_value": contract_value,
        "boq_value": boq_value,
        "total_expenses": expenses,
        "total_invoiced": invoiced,
        "total_received": received,
        "receivable": max(invoiced - received, 0),
        "projected_profit": contract_value - expenses,
        "cash_profit": received - expenses,
    }
