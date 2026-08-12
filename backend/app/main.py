from fastapi import FastAPI

from app.api import attendance, auth, commercial, employees, operations
from app.core.config import settings
from app.db.session import Base, engine
from app.models import commercial as commercial_models  # noqa: F401
from app.models import core, operations as operations_models  # noqa: F401


Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version="0.4.0",
    description="Backend API for Choudhary & Sons contractor and supplier management platform.",
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(employees.router, prefix="/api/v1")
app.include_router(attendance.router, prefix="/api/v1")
app.include_router(operations.router, prefix="/api/v1")
app.include_router(commercial.router, prefix="/api/v1")


@app.get("/")
def root():
    return {
        "name": settings.app_name,
        "status": "running",
        "version": "0.4.0",
    }


@app.get("/health")
def health():
    return {"status": "ok"}


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
            "safety",
            "documents",
            "reports",
        ]
    }
