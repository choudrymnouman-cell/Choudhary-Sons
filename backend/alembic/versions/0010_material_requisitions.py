"""Material requisitions linked to purchase orders."""
from alembic import op
import sqlalchemy as sa
revision = '0010_material_requisitions'
down_revision = '0009_project_tasks'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('material_requisitions',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('project_id', sa.Integer(), sa.ForeignKey('projects.id'), nullable=False),
        sa.Column('material_id', sa.Integer(), sa.ForeignKey('materials.id'), nullable=False),
        sa.Column('quantity', sa.Numeric(14, 3), nullable=False),
        sa.Column('needed_by', sa.Date(), nullable=False),
        sa.Column('purpose', sa.Text(), nullable=False),
        sa.Column('status', sa.String(20), nullable=False),
        sa.Column('requested_by', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('purchase_order_id', sa.Integer(), sa.ForeignKey('purchase_orders.id'), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False))
    op.create_index('ix_material_requisitions_project_id', 'material_requisitions', ['project_id'])


def downgrade():
    op.drop_table('material_requisitions')
