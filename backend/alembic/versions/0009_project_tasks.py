"""Project task and milestone schedule."""
from alembic import op
import sqlalchemy as sa
revision = '0009_project_tasks'
down_revision = '0008_project_assignments'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('project_tasks',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('project_id', sa.Integer(), sa.ForeignKey('projects.id'), nullable=False),
        sa.Column('title', sa.String(200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('kind', sa.String(20), nullable=False),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('due_date', sa.Date(), nullable=False),
        sa.Column('progress', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(20), nullable=False),
        sa.Column('created_by', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False))
    op.create_index('ix_project_tasks_project_id', 'project_tasks', ['project_id'])


def downgrade():
    op.drop_table('project_tasks')
