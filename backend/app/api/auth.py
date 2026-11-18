from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select, func
from sqlalchemy.exc import IntegrityError
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.security import create_access_token, verify_password, hash_password
from app.models.core import User, UserRole

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
def login(request: Request, form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == form.username))
    if user is None and form.username.lower() != form.username:
        user = db.scalar(select(User).where(User.email == form.username.lower()))
    if not user or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is inactive")

    request.state.audit_actor_id = user.id
    token = create_access_token(str(user.id), user.role.value, token_version=user.token_version)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "role": user.role.value,
        },
    }


@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "full_name": current_user.full_name,
        "email": current_user.email,
        "phone": current_user.phone,
        "role": current_user.role.value,
        "is_active": current_user.is_active,
    }


class Registration(BaseModel):
    full_name: str = Field(min_length=1, max_length=150)
    email: EmailStr
    password: str = Field(min_length=12, max_length=72)

    model_config = {"extra": "forbid"}


@router.post("/signup", status_code=201)
def register(payload: Registration, db: Session = Depends(get_db)):
    name = payload.full_name.strip()
    if not name or len(payload.password.encode()) > 72:
        raise HTTPException(422, "Name required; password must fit within 72 UTF-8 bytes")
    email = payload.email.lower()
    if db.scalar(select(User.id).where(func.lower(User.email) == email)):
        raise HTTPException(409, "An account already exists")
    account = User(full_name=name, email=email, password_hash=hash_password(payload.password), role=UserRole.PENDING)
    db.add(account)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "An account already exists")
    return {"created": True, "status": "pending", "message": "Ask the owner to assign your department."}
