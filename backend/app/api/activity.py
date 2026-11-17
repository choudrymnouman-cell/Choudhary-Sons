import logging

from fastapi import Request

from app.db.session import SessionLocal
from app.models.ownership import ActivityEvent

logger = logging.getLogger(__name__)


def record_activity(request: Request, status_code: int) -> None:
    actor_id = getattr(request.state, "audit_actor_id", None)
    route = request.scope.get("route")
    if actor_id is None or route is None or not route.path.startswith("/api/v1/"):
        return
    resource_id = next((int(value) for value in request.path_params.values()
                        if str(value).isascii() and str(value).isdecimal() and len(str(value)) < 10), None)
    try:
        with SessionLocal() as db:
            db.add(ActivityEvent(
                actor_id=actor_id,
                method=request.method,
                resource=route.path,
                resource_id=resource_id,
                status_code=status_code,
            ))
            db.commit()
    except Exception:
        logger.error("Could not append the activity event for %s", route.path)
