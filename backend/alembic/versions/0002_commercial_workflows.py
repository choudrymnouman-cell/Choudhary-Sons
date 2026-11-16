"""Add stock movements, deliveries, supplier payments, and invoice receipts."""
from alembic import op

from app.models.trade import InvoiceReceipt, PurchaseDelivery, StockMovement, SupplierPayment

revision = "0002_commercial_workflows"
down_revision = "0001_initial_schema"
branch_labels = None
depends_on = None

tables = (StockMovement, PurchaseDelivery, SupplierPayment, InvoiceReceipt)


def upgrade() -> None:
    for model in tables:
        model.__table__.create(op.get_bind(), checkfirst=True)


def downgrade() -> None:
    for model in reversed(tables):
        model.__table__.drop(op.get_bind(), checkfirst=True)
