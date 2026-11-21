from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import AwareDatetime, BaseModel, ConfigDict, EmailStr, Field, HttpUrl
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.core.config import settings
from app.core.security import hash_password
from app.db.session import get_db
from app.models.core import Employee, User, UserRole
from app.models.operations import ApplicationStatus, JobApplication, JobVacancy
from app.models.recruitment import (
    ApplicantApplication, ApplicantFile, ApplicantNotification, ApplicantProfile,
    ApplicationHistory, HrConversation, HrMessage, HrNote, Interview, SavedJob, utcnow,
)

router = APIRouter(prefix="/recruitment", tags=["recruitment"])
hr_roles = (UserRole.OWNER, UserRole.ADMIN, UserRole.HR)
require_hr = require_roles(*hr_roles)
require_applicant = require_roles(UserRole.APPLICANT)
file_fields = {
    "profile_photo_path": "profile_photo",
    "cnic_front_path": "cnic_front",
    "cnic_back_path": "cnic_back",
    "experience_document_path": "experience",
}


class Signup(BaseModel):
    full_name: str = Field(min_length=1, max_length=150)
    email: EmailStr
    password: str = Field(min_length=10, max_length=72, strict=True)
    phone: str | None = Field(default=None, max_length=30)


class ProfileInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    full_name: str = Field(min_length=1, max_length=150)
    father_name: str | None = Field(default=None, max_length=150)
    cnic: str | None = Field(default=None, max_length=30)
    cnic_name: str | None = Field(default=None, max_length=150)
    whatsapp_number: str | None = Field(default=None, max_length=30)
    phone: str | None = Field(default=None, max_length=30)
    education: str | None = Field(default=None, max_length=500)
    experience_years: Decimal = Field(default=Decimal("0"), ge=0, max_digits=5, decimal_places=2)
    experience_details: str | None = Field(default=None, max_length=3000)
    skills: str | None = Field(default=None, max_length=1000)
    bank_account_title: str | None = Field(default=None, max_length=150)
    bank_account_number: str | None = Field(default=None, max_length=60)
    bank_name: str | None = Field(default=None, max_length=150)
    address: str | None = Field(default=None, max_length=500)
    city: str | None = Field(default=None, max_length=150)
    profile_photo_path: str | None = Field(default=None, max_length=32)
    cnic_front_path: str | None = Field(default=None, max_length=32)
    cnic_back_path: str | None = Field(default=None, max_length=32)
    experience_document_path: str | None = Field(default=None, max_length=32)


class Preferences(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    preferred_department: str | None = Field(default=None, max_length=120)
    preferred_location: str | None = Field(default=None, max_length=180)
    preferred_employment_type: str | None = Field(default=None, max_length=50)
    min_expected_salary: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    receive_job_alerts: bool = False


class ApplicationInput(BaseModel):
    vacancy_id: int
    cover_letter: str | None = Field(default=None, max_length=5000)
    expected_salary: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)


class StatusInput(BaseModel):
    status: Literal["shortlisted", "rejected"]


class NoteInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    note: str = Field(min_length=1, max_length=4000)


class ConversationInput(BaseModel):
    application_id: int | None = None
    subject: str = Field(default="General HR Support", max_length=180)


class MessageInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    message: str = Field(min_length=1, max_length=4000)


class InterviewInput(BaseModel):
    scheduled_at: AwareDatetime
    duration_minutes: int = Field(default=30, ge=5, le=480)
    interview_type: Literal["video", "phone", "onsite"] = "video"
    meeting_url: HttpUrl | None = None
    room_code: str | None = Field(default=None, max_length=100)
    notes: str | None = Field(default=None, max_length=4000)


class HireInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    employee_code: str = Field(min_length=1, max_length=30)
    designation: str = Field(min_length=1, max_length=120)
    department: str | None = Field(default=None, max_length=120)
    basic_salary: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    joining_date: date = Field(default_factory=date.today)


def commit_unique(db: Session, message: str) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, message) from exc


def profile_for(db: Session, user: User) -> ApplicantProfile:
    profile = db.get(ApplicantProfile, user.id)
    if profile is None:
        raise HTTPException(404, "Applicant profile not found")
    return profile


def application_for(db: Session, application_id: int, lock: bool = False) -> JobApplication:
    query = select(JobApplication).where(JobApplication.id == application_id)
    app = db.scalar(query.with_for_update() if lock else query)
    if app is None:
        raise HTTPException(404, "Application not found")
    return app


def owned_application(db: Session, application_id: int, user: User) -> ApplicantApplication:
    link = db.get(ApplicantApplication, application_id)
    if link is None or link.user_id != user.id:
        raise HTTPException(404, "Application not found")
    return link


def change_status(db: Session, app: JobApplication, status: ApplicationStatus) -> None:
    if app.status == status:
        return
    if app.status == ApplicationStatus.HIRED:
        raise HTTPException(409, "Applicant has already been hired")
    db.add(ApplicationHistory(application_id=app.id, old_status=app.status.value, new_status=status.value))
    app.status = status
    link = db.get(ApplicantApplication, app.id)
    if link:
        db.add(ApplicantNotification(
            user_id=link.user_id,
            notification_type="interview" if status == ApplicationStatus.INTERVIEW else "application",
            title="Application updated",
            body=f"Your application status is now {status.value}.",
        ))


def application_rows(db: Session, user_id: int | None = None):
    query = (
        select(JobApplication, JobVacancy, ApplicantApplication)
        .join(JobVacancy, JobVacancy.id == JobApplication.vacancy_id)
        .outerjoin(ApplicantApplication, ApplicantApplication.application_id == JobApplication.id)
        .order_by(JobApplication.id.desc())
    )
    if user_id is not None:
        query = query.where(ApplicantApplication.user_id == user_id)
    return [
        {**vars(app), "job_vacancies": job, "applicant_user_id": link.user_id if link else None,
         "expected_salary": link.expected_salary if link else None, "cover_letter": app.cover_note}
        for app, job, link in db.execute(query)
    ]


@router.post("/signup", status_code=201)
def signup(payload: Signup, db: Session = Depends(get_db)):
    if len(payload.password.encode()) > 72:
        raise HTTPException(422, "Password exceeds 72 bytes")
    full_name = payload.full_name.strip()
    if not full_name:
        raise HTTPException(422, "Full name is required")
    email = payload.email.lower()
    if db.scalar(select(User.id).where(func.lower(User.email) == email)):
        raise HTTPException(409, "An account already exists")
    user = User(email=email, full_name=full_name, password_hash=hash_password(payload.password), role=UserRole.APPLICANT)
    try:
        db.add(user)
        db.flush()
        db.add(ApplicantProfile(
            user_id=user.id,
            details={"full_name": full_name, "phone": payload.phone, "whatsapp_number": payload.phone,
                     "is_profile_complete": False},
        ))
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "An account already exists") from exc
    return {"created": True}


@router.get("/profile")
def read_profile(db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    return profile_for(db, user).details


@router.put("/profile")
def update_profile(payload: ProfileInput, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    profile = profile_for(db, user)
    fields = {**profile.details, **payload.model_dump(mode="json", exclude_unset=True)}
    for name, kind in file_fields.items():
        if fields.get(name):
            record = db.get(ApplicantFile, fields[name])
            if record is None or record.user_id != user.id or record.kind != kind:
                raise HTTPException(422, "Invalid applicant document")
    required = ("father_name", "cnic", "cnic_name", "whatsapp_number", "education",
                "profile_photo_path", "cnic_front_path", "cnic_back_path")
    fields["is_profile_complete"] = all(fields.get(key) for key in required) and (
        fields["full_name"].casefold() == fields["cnic_name"].casefold()
    )
    profile.details = fields
    user.full_name = payload.full_name
    db.commit()
    return fields


@router.post("/files/{kind}", status_code=201)
async def upload_file(
    kind: Literal["profile_photo", "cnic_front", "cnic_back", "experience"],
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_applicant),
):
    filename = Path((file.filename or "").replace(chr(92), "/")).name[:255]
    extension = Path(filename).suffix.lower()
    media = {".pdf": b"%PDF-", ".png": b"\x89PNG\r\n\x1a\n", ".jpg": b"\xff\xd8\xff", ".jpeg": b"\xff\xd8\xff"}
    if extension not in media or (kind == "profile_photo" and extension == ".pdf"):
        raise HTTPException(415, "Unsupported file type")
    limit = settings.max_upload_mb * 1024 * 1024
    contents = await file.read(limit + 1)
    if len(contents) > limit:
        raise HTTPException(413, "File is too large")
    if not contents.startswith(media[extension]):
        raise HTTPException(415, "Contents do not match the file type")
    record = ApplicantFile(id=uuid4().hex, user_id=user.id, kind=kind, filename=filename)
    directory = Path(settings.upload_dir) / "applicant"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = directory / record.id
    try:
        with path.open("xb") as target:
            target.write(contents)
        path.chmod(0o600)
        db.add(record)
        db.commit()
    except Exception:
        path.unlink(missing_ok=True)
        raise
    return {"id": record.id}


@router.get("/files/{file_id}")
def download_file(file_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    record = db.get(ApplicantFile, file_id)
    if record is None or (record.user_id != user.id and user.role not in hr_roles):
        raise HTTPException(404, "File not found")
    path = Path(settings.upload_dir) / "applicant" / record.id
    if not path.is_file():
        raise HTTPException(404, "File not found")
    return FileResponse(path, filename=record.filename, media_type="application/octet-stream", headers={
        "Cache-Control": "private, no-store",
        "X-Content-Type-Options": "nosniff",
    })


@router.get("/applications/me")
def my_applications(db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    return application_rows(db, user.id)


@router.post("/applications", status_code=201)
def apply(payload: ApplicationInput, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    profile = profile_for(db, user).details
    if not profile.get("is_profile_complete"):
        raise HTTPException(422, "Complete your profile and identity documents before applying")
    job = db.scalar(select(JobVacancy).where(JobVacancy.id == payload.vacancy_id).with_for_update())
    if job is None or not job.is_open:
        raise HTTPException(404, "Vacancy is not open")
    app = JobApplication(
        vacancy_id=job.id, applicant_name=profile["full_name"], email=user.email,
        phone=profile.get("whatsapp_number") or profile.get("phone"), cnic=profile.get("cnic"),
        experience_years=Decimal(profile.get("experience_years", "0")), cover_note=payload.cover_letter,
    )
    db.add(app)
    db.flush()
    db.add(ApplicantApplication(
        application_id=app.id, user_id=user.id, vacancy_id=job.id, expected_salary=payload.expected_salary,
    ))
    db.add(ApplicationHistory(application_id=app.id, new_status=ApplicationStatus.APPLIED.value))
    commit_unique(db, "You already applied for this job")
    return {"id": app.id}


@router.get("/applications/{application_id}/history")
def history(application_id: int, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    owned_application(db, application_id, user)
    return db.scalars(select(ApplicationHistory).where(
        ApplicationHistory.application_id == application_id
    ).order_by(ApplicationHistory.id)).all()


@router.get("/saved-jobs")
def saved_jobs(db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    query = (
        select(SavedJob, JobVacancy).join(JobVacancy, JobVacancy.id == SavedJob.vacancy_id)
        .where(SavedJob.user_id == user.id).order_by(SavedJob.created_at.desc())
    )
    return [{**vars(saved), "job_vacancies": job} for saved, job in db.execute(query)]


@router.put("/saved-jobs/{vacancy_id}")
def save_job(vacancy_id: int, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    if db.get(JobVacancy, vacancy_id) is None:
        raise HTTPException(404, "Vacancy not found")
    if db.get(SavedJob, (user.id, vacancy_id)) is None:
        db.add(SavedJob(user_id=user.id, vacancy_id=vacancy_id))
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            if db.get(SavedJob, (user.id, vacancy_id)) is None:
                raise
    return {"saved": True}


@router.delete("/saved-jobs/{vacancy_id}")
def unsave_job(vacancy_id: int, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    item = db.get(SavedJob, (user.id, vacancy_id))
    if item is not None:
        db.delete(item)
        db.commit()
    return {"saved": False}


@router.get("/preferences")
def read_preferences(db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    return profile_for(db, user).preferences


@router.put("/preferences")
def save_preferences(payload: Preferences, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    profile = profile_for(db, user)
    profile.preferences = payload.model_dump(mode="json")
    db.commit()
    return profile.preferences


def notify_matching_jobs(db: Session, job: JobVacancy) -> None:
    for profile in db.scalars(select(ApplicantProfile).where(ApplicantProfile.preferences.is_not(None))):
        preferences = profile.preferences or {}
        if not preferences.get("receive_job_alerts"):
            continue
        matches = all(
            not preferences.get(key) or preferences[key].casefold() in (value or "").casefold()
            for key, value in (("preferred_department", job.department), ("preferred_location", job.location),
                               ("preferred_employment_type", job.employment_type))
        )
        minimum = preferences.get("min_expected_salary")
        if matches and (minimum is None or job.salary_max is not None and job.salary_max >= Decimal(minimum)):
            db.add(ApplicantNotification(
                user_id=profile.user_id, notification_type="job_alert", title="New matching vacancy", body=job.title,
            ))


@router.get("/notifications")
def notifications(db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    return db.scalars(select(ApplicantNotification).where(
        ApplicantNotification.user_id == user.id
    ).order_by(ApplicantNotification.id.desc())).all()


@router.patch("/notifications/{notification_id}")
def read_notification(notification_id: int, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    row = db.get(ApplicantNotification, notification_id)
    if row is None or row.user_id != user.id:
        raise HTTPException(404, "Notification not found")
    row.is_read = True
    db.commit()
    return {"is_read": True}


@router.get("/interviews/me")
def my_interviews(db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    return db.scalars(select(Interview).where(
        Interview.applicant_user_id == user.id
    ).order_by(Interview.scheduled_at)).all()


@router.get("/hr/applications")
def hr_applications(db: Session = Depends(get_db), _: User = Depends(require_hr)):
    return application_rows(db)


@router.get("/hr/profiles/{user_id}")
def hr_profile(user_id: int, db: Session = Depends(get_db), _: User = Depends(require_hr)):
    profile = db.get(ApplicantProfile, user_id)
    return profile.details if profile else None


@router.get("/hr/applications/{application_id}/notes")
def hr_notes(application_id: int, db: Session = Depends(get_db), _: User = Depends(require_hr)):
    application_for(db, application_id)
    return db.scalars(select(HrNote).where(HrNote.application_id == application_id).order_by(HrNote.id.desc())).all()


@router.post("/hr/applications/{application_id}/notes", status_code=201)
def add_note(application_id: int, payload: NoteInput, db: Session = Depends(get_db), user: User = Depends(require_hr)):
    application_for(db, application_id)
    db.add(HrNote(application_id=application_id, created_by=user.id, note=payload.note))
    db.commit()
    return {"saved": True}


@router.patch("/hr/applications/{application_id}/status")
def set_status(application_id: int, payload: StatusInput, db: Session = Depends(get_db), _: User = Depends(require_hr)):
    app = application_for(db, application_id, lock=True)
    change_status(db, app, ApplicationStatus(payload.status))
    db.commit()
    return {"status": app.status.value}


@router.post("/hr/applications/{application_id}/interviews", status_code=201)
def schedule(application_id: int, payload: InterviewInput, db: Session = Depends(get_db), user: User = Depends(require_hr)):
    app = application_for(db, application_id, lock=True)
    link = db.get(ApplicantApplication, app.id)
    if link is None:
        raise HTTPException(409, "This application has no applicant account")
    if payload.scheduled_at <= utcnow():
        raise HTTPException(422, "Interview must be scheduled in the future")
    change_status(db, app, ApplicationStatus.INTERVIEW)
    if payload.meeting_url is not None and payload.meeting_url.scheme != "https":
        raise HTTPException(422, "Use an HTTPS meeting URL")
    data = payload.model_dump(exclude={"meeting_url"})
    result = Interview(**data, application_id=app.id, applicant_user_id=link.user_id, hr_user_id=user.id,
                       meeting_url=str(payload.meeting_url) if payload.meeting_url else None)
    db.add(result)
    db.commit()
    db.refresh(result)
    return result


@router.post("/hr/applications/{application_id}/hire", status_code=201)
def hire(application_id: int, payload: HireInput, db: Session = Depends(get_db), actor: User = Depends(require_hr)):
    app = application_for(db, application_id, lock=True)
    link = db.get(ApplicantApplication, app.id)
    if link is None:
        raise HTTPException(409, "This application has no applicant account")
    applicant = db.scalar(select(User).where(User.id == link.user_id).with_for_update())
    if app.status == ApplicationStatus.HIRED:
        current = db.scalar(select(Employee).where(Employee.user_id == applicant.id))
        if current and current.employee_code == payload.employee_code:
            return {"id": current.id}
    if applicant.role != UserRole.APPLICANT:
        raise HTTPException(409, "This account is already a staff account")
    change_status(db, app, ApplicationStatus.HIRED)
    employee = Employee(**payload.model_dump(), user_id=applicant.id, cnic=app.cnic)
    db.add(employee)
    applicant.role = UserRole.EMPLOYEE if actor.role == UserRole.OWNER else UserRole.PENDING
    applicant.token_version += 1
    commit_unique(db, "Employee code or account already exists")
    return {"id": employee.id}


@router.get("/conversations")
def conversations(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    query = select(HrConversation).order_by(HrConversation.updated_at.desc())
    if user.role not in hr_roles:
        if user.role != UserRole.APPLICANT:
            raise HTTPException(403, "Insufficient permissions")
        query = query.where(HrConversation.applicant_user_id == user.id)
    return db.scalars(query).all()


@router.post("/conversations")
def open_conversation(payload: ConversationInput, db: Session = Depends(get_db), user: User = Depends(require_applicant)):
    if payload.application_id is not None:
        owned_application(db, payload.application_id, user)
    key = str(payload.application_id) if payload.application_id is not None else "general"
    query = select(HrConversation).where(
        HrConversation.applicant_user_id == user.id, HrConversation.thread_key == key,
    )
    conversation = db.scalar(query)
    if conversation is None:
        conversation = HrConversation(
            applicant_user_id=user.id, job_application_id=payload.application_id,
            thread_key=key, subject=payload.subject.strip() or "General HR Support",
        )
        db.add(conversation)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            conversation = db.scalar(query)
            if conversation is None:
                raise
        db.refresh(conversation)
    return conversation


def accessible_conversation(db: Session, conversation_id: int, user: User) -> HrConversation:
    conversation = db.get(HrConversation, conversation_id)
    if conversation is None or (conversation.applicant_user_id != user.id and user.role not in hr_roles):
        raise HTTPException(404, "Conversation not found")
    return conversation


@router.get("/conversations/{conversation_id}/messages")
def messages(conversation_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    accessible_conversation(db, conversation_id, user)
    return db.scalars(select(HrMessage).where(HrMessage.conversation_id == conversation_id).order_by(HrMessage.id)).all()


@router.post("/conversations/{conversation_id}/messages", status_code=201)
def send_message(conversation_id: int, payload: MessageInput, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    conversation = accessible_conversation(db, conversation_id, user)
    conversation.updated_at = utcnow()
    result = HrMessage(conversation_id=conversation_id, sender_user_id=user.id, message=payload.message)
    db.add(result)
    if user.role in hr_roles:
        db.add(ApplicantNotification(
            user_id=conversation.applicant_user_id, notification_type="message",
            title="Message from HR", body=conversation.subject,
        ))
    db.commit()
    db.refresh(result)
    return result
