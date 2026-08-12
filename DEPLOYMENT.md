# Choudhary & Sons — Run and Deployment Guide

## Local backend with PostgreSQL

From the repository root:

```bash
docker compose up --build
```

The API will be available on port `8000`. The backend container runs `alembic upgrade head` before starting Uvicorn, so the database schema is created or upgraded before the API accepts traffic.

## Local Flutter app

Run the backend first, then from `mobile/`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a physical Android device, use the computer's LAN IP instead of `10.0.2.2` and make sure the phone can reach that machine.

## Production backend

Required environment variables:

- `ENVIRONMENT=production`
- `DATABASE_URL` — PostgreSQL connection string using the `postgresql+psycopg://` driver
- `SECRET_KEY` — a long random secret that is never committed to Git
- `ACCESS_TOKEN_EXPIRE_MINUTES` — token lifetime
- `APP_NAME` — optional display name

The production container is defined in `backend/Dockerfile`. Its startup command applies Alembic migrations and starts FastAPI/Uvicorn.

## Database changes

When SQLAlchemy models change, create a migration from the `backend/` directory:

```bash
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```

Review generated migrations before applying them to production data.

## Initial owner account

Use the existing bootstrap script from the backend environment to create the first owner/admin account. Never commit real owner credentials or production secrets.

## Release checklist

Before a production release:

1. Use a managed PostgreSQL database and backups.
2. Replace every development secret/password.
3. Apply migrations against a staging copy first.
4. Build the Flutter app with the deployed HTTPS API URL.
5. Test owner, admin, employee and restricted-role access separately.
6. Test attendance, payroll, leave, projects, purchasing, invoicing, field reports and safety flows with realistic data.
7. Verify restore procedures for the database and uploaded documents before relying on the system operationally.
