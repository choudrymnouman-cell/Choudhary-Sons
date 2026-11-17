"""Add owner approval queue and thresholds."""
from alembic import op

from app.models.ownership import ApprovalRequest, ApprovalSettings

revision = "0005_owner_approvals"
down_revision = "0004_owner_console"
branch_labels = None
depends_on = None


def upgrade() -> None:
    ApprovalSettings.__table__.create(op.get_bind())
    ApprovalRequest.__table__.create(op.get_bind())


def downgrade() -> None:
    ApprovalRequest.__table__.drop(op.get_bind())
    ApprovalSettings.__table__.drop(op.get_bind())
