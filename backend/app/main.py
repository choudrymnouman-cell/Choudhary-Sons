from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.concurrency import run_in_threadpool

from app.api import approvals, attendance, auth, commercial, documents, employees, field_ops, operations, owner, recruitment, trade
from app.api.activity import record_activity
from app.core.config import settings
from app.db.session import Base, engine
from app.models import commercial as commercial_models  # noqa: F401
from app.models import field_ops as field_ops_models  # noqa: F401
from app.models import core, operations as operations_models  # noqa: F401


# Local development can bootstrap an empty SQLite database automatically.
# Production environments should run Alembic migrations before starting Uvicorn.
if settings.environment.lower() == "development":
    Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version="0.9.0",
    description="Backend API for Choudhary & Sons contractor and supplier management platform.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def audit_activity(request: Request, call_next):
    response = await call_next(request)
    await run_in_threadpool(record_activity, request, response.status_code)
    return response


app.include_router(approvals.router, prefix="/api/v1")
app.include_router(owner.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(employees.router, prefix="/api/v1")
app.include_router(attendance.router, prefix="/api/v1")
app.include_router(operations.router, prefix="/api/v1")
app.include_router(recruitment.router, prefix="/api/v1")
app.include_router(commercial.router, prefix="/api/v1")
app.include_router(trade.router, prefix="/api/v1")
app.include_router(field_ops.router, prefix="/api/v1")
app.include_router(documents.router, prefix="/api/v1")


@app.get("/")
def root():
    return {
        "name": settings.app_name,
        "status": "running",
        "version": "0.9.0",
        "environment": settings.environment,
        "supabase_storage": settings.supabase_storage_enabled,
    }


@app.get("/health")
def health():
    return {"status": "ok", "version": "0.9.0"}


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
            "supabase_storage",
            "notices",
            "dashboard_kpis",
            "reports",
            "web",
        ]
    }

# Serve the optional release bundle on the same origin as the API.
web_dir = Path("/app/web")
if (web_dir / "index.html").is_file():
    app.mount("/web", StaticFiles(directory=web_dir, html=True), name="web")
