from fastapi import FastAPI

from app.api import attendance, auth, employees
from app.core.config import settings
from app.db.session import Base, engine
from app.models import core  # noqa: F401


Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version="0.2.0",
    description="Backend API for Choudhary & Sons contractor and supplier management platform.",
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(employees.router, prefix="/api/v1")
app.include_router(attendance.router, prefix="/api/v1")


@app.get("/")
def root():
    return {
        "name": settings.app_name,
        "status": "running",
        "version": "0.2.0",
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
            "boq",
            "suppliers",
            "procurement",
            "inventory",
            "finance",
            "assets",
            "safety",
            "documents",
            "reports",
        ]
    }
