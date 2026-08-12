import os

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import Base, SessionLocal, engine
from app.models.core import User, UserRole


def main() -> None:
    email = os.getenv("OWNER_EMAIL")
    password = os.getenv("OWNER_PASSWORD")
    full_name = os.getenv("OWNER_NAME", "Choudhary & Sons Owner")
    phone = os.getenv("OWNER_PHONE")

    if not email or not password:
        raise SystemExit("Set OWNER_EMAIL and OWNER_PASSWORD before running this script.")

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        existing = db.scalar(select(User).where(User.email == email))
        if existing:
            print(f"Owner/user already exists: {email}")
            return

        owner = User(
            full_name=full_name,
            email=email,
            phone=phone,
            password_hash=hash_password(password),
            role=UserRole.OWNER,
            is_active=True,
        )
        db.add(owner)
        db.commit()
        print(f"Owner created: {email}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
