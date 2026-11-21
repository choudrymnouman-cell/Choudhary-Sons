"""Shared project-scoping rules for site and project managers."""
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.core import Project, User, UserProjectAssignment, UserRole

SCOPED_ROLES = {UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR}


def assigned_project_ids(db: Session, user: User):
    return select(UserProjectAssignment.project_id).where(UserProjectAssignment.user_id == user.id)


def project_query(query, column, db: Session, user: User):
    if user.role in SCOPED_ROLES:
        return query.filter(column.in_(assigned_project_ids(db, user)))
    return query


def require_project(db: Session, user: User, project_id: int | None):
    if project_id is None:
        if user.role in SCOPED_ROLES:
            raise HTTPException(403, "Choose an assigned project")
        return
    if not db.get(Project, project_id):
        raise HTTPException(404, "Project not found")
    if user.role in SCOPED_ROLES and db.scalar(select(UserProjectAssignment.user_id).where(
        UserProjectAssignment.user_id == user.id, UserProjectAssignment.project_id == project_id
    )) is None:
        raise HTTPException(403, "You are not assigned to this project")
