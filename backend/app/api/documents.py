from datetime import date
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_roles
from app.core.config import settings
from app.core.supabase_storage import SupabaseStorageError, create_signed_url, upload_bytes
from app.models.core import Employee, Project, User, UserRole
from app.models.field_ops import CompanyDocument

router = APIRouter(tags=["documents"])

DOCUMENT_MANAGEMENT = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.HR,
    UserRole.ACCOUNTANT,
    UserRole.PROJECT_MANAGER,
    UserRole.SITE_SUPERVISOR,
]
ALLOWED_DOCUMENT_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".doc", ".docx", ".xls", ".xlsx"}


@router.post("/documents/supabase", status_code=201)
async def upload_document_to_supabase(
    title: str = Form(...),
    document_type: str = Form(...),
    project_id: int | None = Form(None),
    employee_id: int | None = Form(None),
    expiry_date: date | None = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DOCUMENT_MANAGEMENT)),
):
    if not settings.supabase_storage_enabled:
        raise HTTPException(status_code=503, detail="Supabase Storage is not configured on the backend")
    if project_id is not None and not db.get(Project, project_id):
        raise HTTPException(status_code=404, detail="Project not found")
    if employee_id is not None and not db.get(Employee, employee_id):
        raise HTTPException(status_code=404, detail="Employee not found")
    if project_id is None and employee_id is None:
        raise HTTPException(status_code=400, detail="Attach the document to a project or employee")

    original_name = Path(file.filename or "upload").name
    extension = Path(original_name).suffix.lower()
    if extension not in ALLOWED_DOCUMENT_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported file type")

    max_bytes = settings.max_upload_mb * 1024 * 1024
    contents = await file.read(max_bytes + 1)
    if len(contents) > max_bytes:
        raise HTTPException(status_code=413, detail=f"File exceeds {settings.max_upload_mb} MB limit")

    owner_folder = f"project-{project_id}" if project_id is not None else f"employee-{employee_id}"
    storage_path = f"{owner_folder}/{uuid4().hex}{extension}"
    content_type = file.content_type or "application/octet-stream"

    try:
        file_url = upload_bytes(storage_path, contents, content_type)
    except SupabaseStorageError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    document = CompanyDocument(
        project_id=project_id,
        employee_id=employee_id,
        title=title.strip(),
        document_type=document_type.strip(),
        file_url=file_url,
        expiry_date=expiry_date,
        uploaded_by=user.id,
    )
    db.add(document)
    db.commit()
    db.refresh(document)
    return document


@router.get("/documents/{document_id}/download-url")
def document_download_url(
    document_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(*DOCUMENT_MANAGEMENT)),
):
    document = db.get(CompanyDocument, document_id)
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    if not document.file_url.startswith("supabase://"):
        return {"url": document.file_url, "expires_in": None}

    try:
        url = create_signed_url(document.file_url, expires_in=3600)
    except SupabaseStorageError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return {"url": url, "expires_in": 3600}
