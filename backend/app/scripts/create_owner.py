import argparse
import os
from getpass import getpass

from email_validator import EmailNotValidError, validate_email

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import Base, SessionLocal, engine
from app.models.core import User, UserRole


def main(*, interactive: bool = False) -> None:
    email = os.getenv("OWNER_EMAIL")
    password = os.getenv("OWNER_PASSWORD")
    full_name = os.getenv("OWNER_NAME", "Choudhary & Sons Owner")
    phone = os.getenv("OWNER_PHONE")

    if interactive:
        try:
            email = validate_email(input("Owner email: ").strip(), check_deliverability=False).normalized.lower()
        except EmailNotValidError as exc:
            raise SystemExit(str(exc)) from exc
        password = getpass("New owner password: ")
        if len(password) < 12 or len(password.encode()) > 72:
            raise SystemExit("Use at least 12 characters and at most 72 UTF-8 bytes.")
        if password != getpass("Confirm owner password: "):
            raise SystemExit("Passwords do not match.")

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
    parser = argparse.ArgumentParser()
    parser.add_argument("--interactive", action="store_true", help="Prompt for owner email and password")
    main(interactive=parser.parse_args().interactive)
