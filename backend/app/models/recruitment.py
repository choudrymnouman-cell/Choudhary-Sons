from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def utcnow():
    return datetime.now(timezone.utc)


class ApplicantProfile(Base):
    __tablename__ = "applicant_profiles"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    details: Mapped[dict] = mapped_column(JSON)
    preferences: Mapped[dict | None] = mapped_column(JSON)


class ApplicantFile(Base):
    __tablename__ = "applicant_files"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(30))
    filename: Mapped[str] = mapped_column(String(255))


class ApplicantApplication(Base):
    __tablename__ = "applicant_applications"
    __table_args__ = (UniqueConstraint("user_id", "vacancy_id"),)

    application_id: Mapped[int] = mapped_column(ForeignKey("job_applications.id"), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    vacancy_id: Mapped[int] = mapped_column(ForeignKey("job_vacancies.id"))
    expected_salary: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))


class SavedJob(Base):
    __tablename__ = "saved_jobs"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    vacancy_id: Mapped[int] = mapped_column(ForeignKey("job_vacancies.id"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ApplicantNotification(Base):
    __tablename__ = "applicant_notifications"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    notification_type: Mapped[str] = mapped_column(String(30))
    title: Mapped[str] = mapped_column(String(180))
    body: Mapped[str] = mapped_column(Text)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ApplicationHistory(Base):
    __tablename__ = "application_status_history"

    id: Mapped[int] = mapped_column(primary_key=True)
    application_id: Mapped[int] = mapped_column(ForeignKey("job_applications.id"), index=True)
    old_status: Mapped[str | None] = mapped_column(String(30))
    new_status: Mapped[str] = mapped_column(String(30))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class HrNote(Base):
    __tablename__ = "hr_application_notes"

    id: Mapped[int] = mapped_column(primary_key=True)
    application_id: Mapped[int] = mapped_column(ForeignKey("job_applications.id"), index=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    note: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Interview(Base):
    __tablename__ = "interviews"

    id: Mapped[int] = mapped_column(primary_key=True)
    application_id: Mapped[int] = mapped_column(ForeignKey("job_applications.id"))
    applicant_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    hr_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    duration_minutes: Mapped[int]
    interview_type: Mapped[str] = mapped_column(String(30))
    meeting_url: Mapped[str | None] = mapped_column(String(500))
    room_code: Mapped[str | None] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(String(30), default="scheduled")
    notes: Mapped[str | None] = mapped_column(Text)


class HrConversation(Base):
    __tablename__ = "hr_conversations"
    __table_args__ = (UniqueConstraint("applicant_user_id", "thread_key"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    applicant_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    job_application_id: Mapped[int | None] = mapped_column(ForeignKey("job_applications.id"))
    thread_key: Mapped[str] = mapped_column(String(30))
    subject: Mapped[str] = mapped_column(String(180))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class HrMessage(Base):
    __tablename__ = "hr_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("hr_conversations.id"), index=True)
    sender_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    message: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
