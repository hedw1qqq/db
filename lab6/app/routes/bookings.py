from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Query
from sqlalchemy import func, or_
from sqlmodel import select

from ..db import SessionDep
from ..helpers import (
    calculate_booking_amount,
    count_rows,
    delete_and_snapshot,
    ensure_booking_payload,
    ensure_sort_field,
    get_or_404,
    page_from_models,
    pick_order,
    save_and_refresh,
    to_schema,
)
from ..models import Booking, BookingCreate, BookingPage, BookingRead, BookingUpdate, Message, Order


router = APIRouter(prefix="/bookings", tags=["bookings"])


@router.get("", response_model=BookingPage)
def list_bookings(
    session: SessionDep,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=100),
    sort: str = "id",
    order: Order = "asc",
    filter: str | None = None,
    estate_id: int | None = None,
    guest_id: int | None = None,
):
    # Для бронирований строковый filter трактуем как id, чтобы не плодить лишние поля запроса.
    statement = select(Booking)
    count_statement = select(func.count()).select_from(Booking)

    if estate_id is not None:
        statement = statement.where(Booking.estate_id == estate_id)
        count_statement = count_statement.where(Booking.estate_id == estate_id)

    if guest_id is not None:
        statement = statement.where(Booking.guest_id == guest_id)
        count_statement = count_statement.where(Booking.guest_id == guest_id)

    if filter:
        try:
            value = int(filter)
        except ValueError:
            value = None
        if value is not None:
            condition = or_(
                Booking.id == value,
                Booking.estate_id == value,
                Booking.guest_id == value,
            )
            statement = statement.where(condition)
            count_statement = count_statement.where(condition)

    order_column = ensure_sort_field(
        sort,
        {
            "id": Booking.id,
            "start_date": Booking.start_date,
            "end_date": Booking.end_date,
            "total_price": Booking.total_price,
            "created_at": Booking.created_at,
        },
        "id",
    )
    statement = statement.order_by(pick_order(order_column, order)).offset((page - 1) * limit).limit(limit)

    bookings = session.exec(statement).all()
    total = count_rows(session, count_statement)
    return page_from_models(BookingRead, bookings, page, limit, total)


@router.get("/{booking_id}", response_model=BookingRead, responses={404: {"model": Message}})
def get_booking(booking_id: int, session: SessionDep):
    booking = get_or_404(session, Booking, booking_id, "Booking not found")
    return to_schema(BookingRead, booking)


@router.post("", response_model=BookingRead, status_code=201, responses={409: {"model": Message}})
def create_booking(payload: BookingCreate, session: SessionDep):
    # Итоговую сумму считаем в БД той же функцией, что используется в SQL-части лабораторных.
    ensure_booking_payload(
        session,
        payload.estate_id,
        payload.guest_id,
        payload.start_date,
        payload.end_date,
    )
    booking = Booking(
        **payload.model_dump(),
        total_price=calculate_booking_amount(
            session,
            payload.estate_id,
            payload.start_date,
            payload.end_date,
        ),
        created_at=datetime.utcnow(),
    )
    return to_schema(BookingRead, save_and_refresh(session, booking))


@router.put("/{booking_id}", response_model=BookingRead, responses={404: {"model": Message}})
def update_booking(booking_id: int, payload: BookingUpdate, session: SessionDep):
    booking = get_or_404(session, Booking, booking_id, "Booking not found")

    next_estate_id = payload.estate_id or booking.estate_id
    next_guest_id = payload.guest_id or booking.guest_id
    next_start_date = payload.start_date or booking.start_date
    next_end_date = payload.end_date or booking.end_date

    # Проверяем уже "следующее" состояние брони, а не только присланные поля по отдельности.
    ensure_booking_payload(session, next_estate_id, next_guest_id, next_start_date, next_end_date)

    booking.estate_id = next_estate_id
    booking.guest_id = next_guest_id
    booking.start_date = next_start_date
    booking.end_date = next_end_date
    booking.total_price = calculate_booking_amount(session, next_estate_id, next_start_date, next_end_date)

    return to_schema(BookingRead, save_and_refresh(session, booking))


@router.delete("/{booking_id}", response_model=BookingRead, responses={404: {"model": Message}})
def delete_booking(booking_id: int, session: SessionDep):
    booking = get_or_404(session, Booking, booking_id, "Booking not found")
    return delete_and_snapshot(session, booking, BookingRead)
