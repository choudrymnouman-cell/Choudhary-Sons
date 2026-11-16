"""Add applicant and recruitment workflows."""
from alembic import op

from app.models.recruitment import (
    ApplicantApplication, ApplicantFile, ApplicantNotification, ApplicantProfile,
    ApplicationHistory, HrConversation, HrMessage, HrNote, Interview, SavedJob,
)

revision = "0003_recruitment_workflows"
down_revision = "0002_commercial_workflows"
branch_labels = None
depends_on = None

tables = (
    ApplicantProfile, ApplicantFile, ApplicantApplication, SavedJob, ApplicantNotification,
    ApplicationHistory, HrNote, Interview, HrConversation, HrMessage,
)


def upgrade() -> None:
    for model in tables:
        model.__table__.create(op.get_bind(), checkfirst=True)


def downgrade() -> None:
    for model in reversed(tables):
        model.__table__.drop(op.get_bind(), checkfirst=True)
