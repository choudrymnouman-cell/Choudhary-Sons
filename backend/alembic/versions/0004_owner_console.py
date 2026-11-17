"""Add activity tracking and per-account session revocation."""
import sqlalchemy as sa
from alembic import op

from app.models.ownership import ActivityEvent

revision = "0004_owner_console"
down_revision = "0003_recruitment_workflows"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The original baseline uses the current metadata on a fresh installation.
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("users")}
    if "token_version" not in columns:
        op.add_column("users", sa.Column("token_version", sa.Integer(), server_default=sa.text("0"), nullable=False))
    ActivityEvent.__table__.create(op.get_bind())


def downgrade() -> None:
    ActivityEvent.__table__.drop(op.get_bind())
    op.drop_column("users", "token_version")
