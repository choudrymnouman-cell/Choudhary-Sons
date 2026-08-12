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


def upgrade() -> None:
    Base.metadata.create_all(bind=op.get_bind())


def downgrade() -> None:
    Base.metadata.drop_all(bind=op.get_bind())
