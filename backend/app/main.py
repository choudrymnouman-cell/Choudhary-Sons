from fastapi import FastAPI

from app.core.config import settings
from app.db.session import Base, engine
from app.models import core  # noqa: F401


Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Backend API for Choudhary & Sons contractor and supplier management platform.",
)


@app.get("/")
def root():
    return {
        "name": settings.app_name,
        "status": "running",
        "version": "0.1.0",
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/v1/modules")
def modules():
    return {
        "modules": [
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
