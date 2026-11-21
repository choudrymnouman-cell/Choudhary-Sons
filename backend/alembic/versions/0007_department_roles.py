"""Department roles and pending registration, preserving existing accounts."""
from alembic import op
revision = "0007_department_roles"
down_revision = "0006_tender_tracking"
branch_labels = None
depends_on = None


def upgrade():
    if op.get_bind().dialect.name == "postgresql":
        with op.get_context().autocommit_block():
            for value in ("PENDING", "PROCUREMENT", "STORE", "ESTIMATOR", "EQUIPMENT"):
                op.execute(f"ALTER TYPE userrole ADD VALUE IF NOT EXISTS '{value}'")


def downgrade():
    # PostgreSQL enum values cannot safely be removed while assigned to accounts.
    pass
