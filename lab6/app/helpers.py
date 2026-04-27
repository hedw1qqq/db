from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any, TypeVar

from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, DataError, IntegrityError, ProgrammingError
from pydantic import BaseModel
from sqlmodel import Session

from .models import Estate, Order, User, UserRole


# Нормализуем значения для ответов из raw SQL и представлений.
def convert_value(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def serialize_mapping(row: dict[str, Any]) -> dict[str, Any]:
    return jsonable_encoder({key: convert_value(value) for key, value in row.items()})


SchemaT = TypeVar("SchemaT", bound=BaseModel)
DB_WRITE_EXCEPTIONS = (IntegrityError, DataError, ProgrammingError, DBAPIError)


def to_schema(schema_type: type[SchemaT], source: Any) -> SchemaT:
    return schema_type.model_validate(source)


def page_payload(items: list[Any], page: int, limit: int, total: int) -> dict[str, Any]:
    return {
        "page": page,
        "limit": limit,
        "total": total,
        "items": items,
    }


def page_from_models(
    schema_type: type[SchemaT],
    items: list[Any],
    page: int,
    limit: int,
    total: int,
) -> dict[str, Any]:
    return page_payload([to_schema(schema_type, item) for item in items], page, limit, total)


def db_exception_to_http(exc: Exception) -> HTTPException:
    original = getattr(exc, "orig", exc)
    message = str(original)
    sqlstate = getattr(original, "sqlstate", None) or getattr(original, "pgcode", None)
    lowered = message.lower()

    if sqlstate == "23505" or "duplicate key" in lowered:
        return HTTPException(status_code=409, detail="Unique constraint violation")
    if sqlstate == "23503" or "foreign key" in lowered:
        return HTTPException(status_code=409, detail="Foreign key violation")
    if sqlstate == "23514" or "check constraint" in lowered:
        return HTTPException(status_code=400, detail=message)
    if sqlstate == "40001":
        return HTTPException(status_code=409, detail="Serialization failure, retry the request")

    return HTTPException(status_code=400, detail=message)


def get_or_404(session: Session, model_type, entity_id: Any, detail: str):
    entity = session.get(model_type, entity_id)
    if entity is None:
        raise HTTPException(status_code=404, detail=detail)
    return entity


def commit_or_raise(session: Session) -> None:
    try:
        session.commit()
    except DB_WRITE_EXCEPTIONS as exc:
        session.rollback()
        raise db_exception_to_http(exc)


# Общие CRUD-хелперы нужны, чтобы не дублировать один и тот же commit/refresh/delete в роутерах.
def save_and_refresh(session: Session, entity: Any):
    session.add(entity)
    commit_or_raise(session)
    session.refresh(entity)
    return entity


def delete_and_snapshot(session: Session, entity: Any, schema_type: type[SchemaT]) -> SchemaT:
    payload = to_schema(schema_type, entity)
    session.delete(entity)
    commit_or_raise(session)
    return payload


def count_rows(session: Session, statement) -> int:
    value = session.exec(statement).one()
    if isinstance(value, tuple):
        return int(value[0])
    return int(value)


def pick_order(column, order: Order):
    return column.asc() if order == "asc" else column.desc()


def ensure_sort_field(name: str, allowed: dict[str, Any], default: str):
    return allowed.get(name, allowed[default])


def calculate_booking_amount(session: Session, estate_id: int, start_date: date, end_date: date) -> float:
    amount = session.execute(
        text("SELECT fn_calc_booking_amount(:estate_id, :start_date, :end_date) AS amount"),
        {
            "estate_id": estate_id,
            "start_date": start_date,
            "end_date": end_date,
        },
    ).scalar_one()
    return float(amount)


def ensure_booking_payload(
    session: Session,
    estate_id: int,
    guest_id: int,
    start_date: date,
    end_date: date,
) -> None:
    # Часть проверок дублирует триггеры БД, но здесь они дают более понятный HTTP-ответ.
    if start_date >= end_date:
        raise HTTPException(status_code=400, detail="start_date must be earlier than end_date")

    estate = session.get(Estate, estate_id)
    if not estate:
        raise HTTPException(status_code=404, detail="Estate not found")

    guest = session.get(User, guest_id)
    if not guest:
        raise HTTPException(status_code=404, detail="Guest not found")

    if guest.role not in {UserRole.guest, UserRole.both}:
        raise HTTPException(status_code=409, detail="Selected user cannot act as a guest")

    if estate.host_id == guest_id:
        raise HTTPException(status_code=409, detail="Host cannot book their own estate")

    if start_date < estate.available_from or end_date > estate.available_to:
        raise HTTPException(status_code=409, detail="Booking dates are outside the estate availability window")


def run_paged_view_query(
    session: Session,
    view_name: str,
    allowed_sorts: set[str],
    sort: str,
    order: Order,
    page: int,
    limit: int,
    filters: list[str],
    params: dict[str, Any],
) -> dict[str, Any]:
    # Здесь сортировка ограничена белым списком, чтобы не собирать небезопасный SQL.
    safe_sort = sort if sort in allowed_sorts else next(iter(sorted(allowed_sorts)))
    where_sql = f" WHERE {' AND '.join(filters)}" if filters else ""
    offset = (page - 1) * limit
    query_sql = text(
        f"SELECT * FROM {view_name}{where_sql} ORDER BY {safe_sort} {'ASC' if order == 'asc' else 'DESC'} LIMIT :limit OFFSET :offset"
    )
    count_sql = text(f"SELECT COUNT(*) FROM {view_name}{where_sql}")
    query_params = {**params, "limit": limit, "offset": offset}
    items = [serialize_mapping(dict(row)) for row in session.execute(query_sql, query_params).mappings().all()]
    total = int(session.execute(count_sql, params).scalar_one())
    return page_payload(items, page, limit, total)
