"""Create initial Choudhary & Sons schema.

Revision ID: 0001_initial_schema
Revises:
"""
from alembic import op

from app.db.session import Base
from app.models import commercial as commercial_models  # noqa: F401
from app.models import field_ops as field_ops_models  # noqa: F401
from app.models import core, operations as operations_models  # noqa: F401

revision = '0001_initial_schema'
down_revision = None
branch_labels = None
depends_on = None

table_names = (
    "users", "employees", "clients", "projects", "attendance", "job_vacancies",
    "job_applications", "leave_requests", "payroll_records", "suppliers", "materials",
    "purchase_orders", "purchase_order_items", "boq_items", "expenses", "client_invoices",
    "assets", "fuel_logs", "maintenance_logs", "site_daily_reports", "safety_incidents",
    "safety_inspections", "company_documents", "notices",
)
tables = [Base.metadata.tables[name] for name in table_names]


def upgrade() -> None:
    Base.metadata.create_all(bind=op.get_bind(), tables=tables)


def downgrade() -> None:
    Base.metadata.drop_all(bind=op.get_bind(), tables=tables)
