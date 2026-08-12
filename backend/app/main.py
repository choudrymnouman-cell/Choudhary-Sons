from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import attendance, auth, commercial, employees, field_ops, operations
from app.core.config import settings
from app.db.session import Base, engine
from app.models import commercial as commercial_models  # noqa: F401
from app.models import field_ops as field_ops_models  # noqa: F401
from app.models import core, operations as operations_models  # noqa: F401


# Local development can bootstrap an empty SQLite database automatically.
# Production environments should run Alembic migrations before starting Uvicorn.
if settings.environment.lower() == "development":
    Base.metadata.create_all(bind=engine)

upload_dir = Path(settings.upload_dir)
upload_dir.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title=settings.app_name,
    version="0.8.0",
    description="Backend API for Choudhary & Sons contractor and supplier management platform.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=str(upload_dir)), name="uploads")

app.include_router(auth.router, prefix="/api/v1")
app.include_router(employees.router, prefix="/api/v1")
app.include_router(attendance.router, prefix="/api/v1")
app.include_router(operations.router, prefix="/api/v1")
app.include_router(commercial.router, prefix="/api/v1")
app.include_router(field_ops.router, prefix="/api/v1")


@app.get("/")
def root():
    return {
        "name": settings.app_name,
        "status": "running",
        "version": "0.8.0",
        "environment": settings.environment,
    }


@app.get("/health")
def health():
    return {"status": "ok", "version": "0.8.0"}


@app.get("/api/v1/modules")
def modules():
    return {
        "modules": [
            "auth",
            "employees",
            "attendance",
            "payroll",
            "recruitment",
            "contracts",
            "projects",
            "leave",
            "boq",
            "suppliers",
            "procurement",
            "inventory",
            "expenses",
            "invoices",
            "profitability",
            "assets",
            "fuel",
            "maintenance",
            "site_reports",
            "safety",
            "documents",
            "notices",
            "dashboard_kpis",
            "reports",
            "web",
        ]
    }
