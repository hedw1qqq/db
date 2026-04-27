from __future__ import annotations

from fastapi import APIRouter, Query
from sqlalchemy import func, or_
from sqlmodel import select

from ..db import SessionDep
from ..helpers import (
    count_rows,
    delete_and_snapshot,
    ensure_sort_field,
    get_or_404,
    page_from_models,
    pick_order,
    save_and_refresh,
    to_schema,
)
from ..models import Message, Order, User, UserCreate, UserPage, UserRead, UserRole, UserUpdate


router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=UserPage)
def list_users(
    session: SessionDep,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=100),
    sort: str = "id",
    order: Order = "asc",
    filter: str | None = None,
    role: UserRole | None = None,
):
    # Сначала собираем запрос выборки и отдельный count, чтобы пагинация была честной.
    statement = select(User)
    count_statement = select(func.count()).select_from(User)

    if role is not None:
        statement = statement.where(User.role == role)
        count_statement = count_statement.where(User.role == role)

    if filter:
        condition = or_(
            User.name.ilike(f"%{filter}%"),
            User.email.ilike(f"%{filter}%"),
            User.phone.ilike(f"%{filter}%"),
        )
        statement = statement.where(condition)
        count_statement = count_statement.where(condition)

    order_column = ensure_sort_field(
        sort,
        {"id": User.id, "name": User.name, "email": User.email, "role": User.role},
        "id",
    )
    statement = statement.order_by(pick_order(order_column, order)).offset((page - 1) * limit).limit(limit)

    users = session.exec(statement).all()
    total = count_rows(session, count_statement)
    return page_from_models(UserRead, users, page, limit, total)


@router.get("/{user_id}", response_model=UserRead, responses={404: {"model": Message}})
def get_user(user_id: int, session: SessionDep):
    user = get_or_404(session, User, user_id, "User not found")
    return to_schema(UserRead, user)


@router.post("", response_model=UserRead, status_code=201, responses={409: {"model": Message}})
def create_user(payload: UserCreate, session: SessionDep):
    user = User(**payload.model_dump())
    return to_schema(UserRead, save_and_refresh(session, user))


@router.put("/{user_id}", response_model=UserRead, responses={404: {"model": Message}})
def update_user(user_id: int, payload: UserUpdate, session: SessionDep):
    user = get_or_404(session, User, user_id, "User not found")

    for field_name, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, field_name, value)

    return to_schema(UserRead, save_and_refresh(session, user))


@router.delete("/{user_id}", response_model=UserRead, responses={404: {"model": Message}})
def delete_user(user_id: int, session: SessionDep):
    user = get_or_404(session, User, user_id, "User not found")
    return delete_and_snapshot(session, user, UserRead)
