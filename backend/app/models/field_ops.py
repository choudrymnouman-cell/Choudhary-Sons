from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class Asset(Base):
    __tablename__ = "assets"

    id: Mapped[int] = mapped_column(primary_key=True)
    asset_code: Mapped[str] = mapped_column(String(60), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(180), index=True)
    asset_type: Mapped[str] = mapped_column(String(80), index=True)
    registration_number: Mapped[str | None] = mapped_column(String(80), nullable=True)
    make_model: Mapped[str | None] = mapped_column(String(180), nullable=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(40), default="active")
    current_meter: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    acquired_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class FuelLog(Base):
    __tablename__ = "fuel_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"), index=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    log_date: Mapped[date] = mapped_column(Date, default=date.today, index=True)
    liters: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    rate_per_liter: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    total_cost: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    meter_reading: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    vendor: Mapped[str | None] = mapped_column(String(180), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MaintenanceLog(Base):
    __tablename__ = "maintenance_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"), index=True)
    maintenance_date: Mapped[date] = mapped_column(Date, default=date.today, index=True)
    maintenance_type: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text)
    cost: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    vendor: Mapped[str | None] = mapped_column(String(180), nullable=True)
    next_due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    next_due_meter: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SiteDailyReport(Base):
    __tablename__ = "site_daily_reports"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id"), index=True)
    report_date: Mapped[date] = mapped_column(Date, default=date.today, index=True)
    weather: Mapped[str | None] = mapped_column(String(80), nullable=True)
    workforce_count: Mapped[int] = mapped_column(default=0)
    work_completed: Mapped[str] = mapped_column(Text)
    materials_used: Mapped[str | None] = mapped_column(Text, nullable=True)
    equipment_used: Mapped[str | None] = mapped_column(Text, nullable=True)
    delays_issues: Mapped[str | None] = mapped_column(Text, nullable=True)
    tomorrow_plan: Mapped[str | None] = mapped_column(Text, nullable=True)
    submitted_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SafetyIncident(Base):
    __tablename__ = "safety_incidents"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    incident_date: Mapped[date] = mapped_column(Date, default=date.today, index=True)
    severity: Mapped[str] = mapped_column(String(40), default="minor")
    title: Mapped[str] = mapped_column(String(180))
    description: Mapped[str] = mapped_column(Text)
    injured_person: Mapped[str | None] = mapped_column(String(180), nullable=True)
    corrective_action: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_closed: Mapped[bool] = mapped_column(Boolean, default=False)
    reported_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SafetyInspection(Base):
    __tablename__ = "safety_inspections"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id"), index=True)
    inspection_date: Mapped[date] = mapped_column(Date, default=date.today, index=True)
    inspector: Mapped[str] = mapped_column(String(180))
    score: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)
    findings: Mapped[str | None] = mapped_column(Text, nullable=True)
    action_required: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class CompanyDocument(Base):
    __tablename__ = "company_documents"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    employee_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"), nullable=True, index=True)
    title: Mapped[str] = mapped_column(String(200))
    document_type: Mapped[str] = mapped_column(String(80), index=True)
    file_url: Mapped[str] = mapped_column(Text)
    expiry_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    uploaded_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Notice(Base):
    __tablename__ = "notices"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(180))
    body: Mapped[str] = mapped_column(Text)
    audience: Mapped[str] = mapped_column(String(50), default="all")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
