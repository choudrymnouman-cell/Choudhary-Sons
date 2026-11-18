"""Project assignments and employee work sites."""
from alembic import op
import sqlalchemy as sa
revision = "0008_project_assignments"
down_revision = "0007_department_roles"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("user_project_assignments",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("project_id", sa.Integer(), sa.ForeignKey("projects.id", ondelete="CASCADE"), primary_key=True))
    # Migration 0001 uses current model metadata for fresh installs.
    if "project_id" in {c["name"] for c in sa.inspect(op.get_bind()).get_columns("employees")}:
        return
    with op.batch_alter_table("employees") as batch:
        batch.add_column(sa.Column("project_id", sa.Integer(), nullable=True))
        batch.create_foreign_key("fk_employee_project", "projects", ["project_id"], ["id"])
        batch.create_index("ix_employees_project_id", ["project_id"])


def downgrade():
    with op.batch_alter_table("employees") as batch:
        batch.drop_index("ix_employees_project_id")
        batch.drop_constraint("fk_employee_project", type_="foreignkey")
        batch.drop_column("project_id")
    op.drop_table("user_project_assignments")
