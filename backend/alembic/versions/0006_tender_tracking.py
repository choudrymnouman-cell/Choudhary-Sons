"""Add the tender register."""
from alembic import op

from app.models.tender import Tender

revision = "0006_tender_tracking"
down_revision = "0005_owner_approvals"
branch_labels = None
depends_on = None


def upgrade() -> None:
    Tender.__table__.create(op.get_bind())


def downgrade() -> None:
    Tender.__table__.drop(op.get_bind())
