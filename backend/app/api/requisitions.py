from datetime import date
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.api.approvals import queue_request, required_by_limit
from app.api.deps import get_db, require_roles
from app.api.project_access import project_query, require_project
from app.models.core import User, UserRole
from app.models.commercial import Material, PurchaseOrder, PurchaseOrderItem, Supplier
from app.models.planning import MaterialRequisition

router = APIRouter(prefix='/requisitions', tags=['material-requisitions'])
read_roles = require_roles(UserRole.OWNER, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR, UserRole.PROCUREMENT, UserRole.STORE)
request_roles = require_roles(UserRole.OWNER, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR)


class RequisitionCreate(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    project_id: int
    material_id: int
    quantity: Decimal = Field(gt=0, max_digits=14, decimal_places=3)
    needed_by: date
    purpose: str = Field(min_length=1, max_length=3000)


class OrderCreate(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    supplier_id: int
    po_number: str = Field(min_length=1, max_length=60)
    unit_price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    tax_amount: Decimal = Field(default=Decimal('0'), ge=0, max_digits=14, decimal_places=2)


@router.get('/catalogue')
def catalogue(db: Session = Depends(get_db), _: User = Depends(read_roles)):
    return [{'id':m.id,'name':m.name,'unit':m.unit,'sku':m.sku} for m in db.query(Material).order_by(Material.name).all()]


@router.get('')
def requests(db: Session = Depends(get_db), user: User = Depends(read_roles)):
    rows = project_query(db.query(MaterialRequisition, Material.name, Material.unit).join(Material, Material.id == MaterialRequisition.material_id), MaterialRequisition.project_id, db, user).order_by(MaterialRequisition.id.desc()).all()
    return [{**{c.name:getattr(r,c.name) for c in MaterialRequisition.__table__.columns},'material_name':name,'unit':unit} for r,name,unit in rows]


@router.post('', status_code=201)
def request_material(payload: RequisitionCreate, db: Session = Depends(get_db), user: User = Depends(request_roles)):
    require_project(db, user, payload.project_id)
    if not db.get(Material, payload.material_id):
        raise HTTPException(404, 'Material not found')
    row = MaterialRequisition(**payload.model_dump(), requested_by=user.id)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.post('/{request_id}/cancel')
def cancel(request_id: int, db: Session = Depends(get_db), user: User = Depends(request_roles)):
    row = db.get(MaterialRequisition, request_id, with_for_update=True)
    if not row:
        raise HTTPException(404, 'Material request not found')
    require_project(db, user, row.project_id)
    if user.role != UserRole.OWNER and row.requested_by != user.id:
        raise HTTPException(403, 'Only the requester or owner may cancel')
    if row.status != 'requested':
        raise HTTPException(409, 'Only unprocessed requests can be cancelled')
    row.status = 'cancelled'
    db.commit()
    return {'id': row.id, 'status':row.status}


@router.post('/{request_id}/order', status_code=201)
def order(request_id: int, payload: OrderCreate, db: Session = Depends(get_db),
          user: User = Depends(require_roles(UserRole.OWNER, UserRole.PROCUREMENT))):
    row = db.get(MaterialRequisition, request_id, with_for_update=True)
    if not row:
        raise HTTPException(404, 'Material request not found')
    if row.status != 'requested':
        raise HTTPException(409, 'This request has already been processed')
    if not db.get(Supplier, payload.supplier_id):
        raise HTTPException(404, 'Supplier not found')
    material = db.get(Material, row.material_id)
    subtotal = (row.quantity * payload.unit_price).quantize(Decimal('0.01'))
    total = subtotal + payload.tax_amount
    if total >= Decimal('100000000000000'):
        raise HTTPException(422, 'Order total is too large')
    pending = required_by_limit(db, 'purchase_order', total)
    po = PurchaseOrder(po_number=payload.po_number, supplier_id=payload.supplier_id,
        project_id=row.project_id, order_date=date.today(), expected_date=row.needed_by,
        subtotal=subtotal, tax_amount=payload.tax_amount, total_amount=total,
        status='pending_approval' if pending else 'draft', notes=f'Material request #{row.id}: {row.purpose}')
    db.add(po)
    try:
        db.flush()
        db.add(PurchaseOrderItem(purchase_order_id=po.id, material_id=row.material_id,
            description=material.name, quantity=row.quantity, unit_price=payload.unit_price,
            unit=material.unit, line_total=subtotal))
        row.purchase_order_id = po.id
        row.status = 'ordered'
        if pending:
            queue_request(db, kind='purchase_order', user_id=user.id,
                          description=f'Purchase order {po.po_number}', record_id=po.id, amount=total)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, 'Purchase order number is already used')
    db.refresh(po)
    return po
