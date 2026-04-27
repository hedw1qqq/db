from __future__ import annotations

from datetime import datetime

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
from ..models import Estate, EstateCreate, EstatePage, EstateRead, EstateUpdate, Message, Order


router = APIRouter(prefix="/estates", tags=["estates"])


@router.get("", response_model=EstatePage)
def list_estates(
    session: SessionDep,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=100),
    sort: str = "id",
    order: Order = "asc",
    filter: str | None = None,
    host_id: int | None = None,
    location: str | None = None,
):
    # Фильтры здесь независимы, поэтому их удобно наращивать поверх базового select.
    statement = select(Estate)
    count_statement = select(func.count()).select_from(Estate)

    if host_id is not None:
        statement = statement.where(Estate.host_id == host_id)
        count_statement = count_statement.where(Estate.host_id == host_id)

    if location:
        statement = statement.where(Estate.location.ilike(location))
        count_statement = count_statement.where(Estate.location.ilike(location))

    if filter:
        condition = or_(
            Estate.name.ilike(f"%{filter}%"),
            Estate.description.ilike(f"%{filter}%"),
            Estate.location.ilike(f"%{filter}%"),
        )
        statement = statement.where(condition)
        count_statement = count_statement.where(condition)

    order_column = ensure_sort_field(
        sort,
        {
            "id": Estate.id,
            "name": Estate.name,
            "location": Estate.location,
            "price_per_night": Estate.price_per_night,
            "created_at": Estate.created_at,
        },
        "id",
    )
    statement = statement.order_by(pick_order(order_column, order)).offset((page - 1) * limit).limit(limit)

    estates = session.exec(statement).all()
    total = count_rows(session, count_statement)
    return page_from_models(EstateRead, estates, page, limit, total)


@router.get("/{estate_id}", response_model=EstateRead, responses={404: {"model": Message}})
def get_estate(estate_id: int, session: SessionDep):
    estate = get_or_404(session, Estate, estate_id, "Estate not found")
    return to_schema(EstateRead, estate)


@router.post("", response_model=EstateRead, status_code=201, responses={409: {"model": Message}})
def create_estate(payload: EstateCreate, session: SessionDep):
    estate = Estate(**payload.model_dump(), created_at=datetime.utcnow())
    return to_schema(EstateRead, save_and_refresh(session, estate))


@router.put("/{estate_id}", response_model=EstateRead, responses={404: {"model": Message}})
def update_estate(estate_id: int, payload: EstateUpdate, session: SessionDep):
    estate = get_or_404(session, Estate, estate_id, "Estate not found")

    for field_name, value in payload.model_dump(exclude_unset=True).items():
        setattr(estate, field_name, value)

    return to_schema(EstateRead, save_and_refresh(session, estate))


@router.delete("/{estate_id}", response_model=EstateRead, responses={404: {"model": Message}})
def delete_estate(estate_id: int, session: SessionDep):
    estate = get_or_404(session, Estate, estate_id, "Estate not found")
    return delete_and_snapshot(session, estate, EstateRead)
