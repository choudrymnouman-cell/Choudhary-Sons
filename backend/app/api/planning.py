from datetime import date
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy.orm import Session
from app.api.deps import get_db, require_roles
from app.api.project_access import project_query, require_project
from app.models.core import Project, ProjectStatus, User, UserRole
from app.models.planning import ProjectTask

router = APIRouter(prefix='/planning', tags=['project-planning'])
read_roles = require_roles(UserRole.OWNER, UserRole.PROJECT_MANAGER, UserRole.SITE_SUPERVISOR)
plan_roles = require_roles(UserRole.OWNER, UserRole.PROJECT_MANAGER)


class TaskCreate(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    project_id: int
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    kind: Literal['task', 'milestone'] = 'task'
    start_date: date
    due_date: date

    @model_validator(mode='after')
    def dates(self):
        if self.due_date < self.start_date:
            raise ValueError('Due date cannot precede start date')
        return self


class TaskProgress(BaseModel):
    progress: int = Field(ge=0, le=100)
    status: Literal['planned', 'in_progress', 'blocked', 'completed']

    @model_validator(mode='after')
    def consistent(self):
        if (self.status == 'completed') != (self.progress == 100):
            raise ValueError('Completed work must have 100% progress; other statuses must be below 100%')
        if self.status == 'planned' and self.progress != 0:
            raise ValueError('Planned work must have 0% progress')
        return self


def editable_project(db, user, project_id):
    require_project(db, user, project_id)
    project = db.get(Project, project_id)
    if project.status in {ProjectStatus.COMPLETED, ProjectStatus.CANCELLED}:
        raise HTTPException(409, 'Closed projects cannot be edited')


@router.get('/tasks')
def tasks(project_id: int | None = None, db: Session = Depends(get_db), user: User = Depends(read_roles)):
    query = project_query(db.query(ProjectTask), ProjectTask.project_id, db, user)
    if project_id is not None:
        require_project(db, user, project_id)
        query = query.filter(ProjectTask.project_id == project_id)
    rows = query.order_by(ProjectTask.start_date, ProjectTask.id).all()
    names = {p.id:p.name for p in db.query(Project).filter(Project.id.in_({r.project_id for r in rows})).all()}
    return [{**{c.name:getattr(t,c.name) for c in ProjectTask.__table__.columns},
             'project_name':names[t.project_id], 'overdue':t.due_date < date.today() and t.progress < 100} for t in rows]


@router.post('/tasks', status_code=201)
def create_task(payload: TaskCreate, db: Session = Depends(get_db), user: User = Depends(plan_roles)):
    editable_project(db, user, payload.project_id)
    task = ProjectTask(**payload.model_dump(), created_by=user.id)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.patch('/tasks/{task_id}/progress')
def progress(task_id: int, payload: TaskProgress, db: Session = Depends(get_db), user: User = Depends(read_roles)):
    task = db.get(ProjectTask, task_id, with_for_update=True)
    if not task:
        raise HTTPException(404, 'Task not found')
    editable_project(db, user, task.project_id)
    task.progress = payload.progress
    task.status = payload.status
    db.commit()
    db.refresh(task)
    return task
