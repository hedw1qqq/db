from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from ..db import SessionDep
from ..helpers import commit_or_raise, get_or_404, to_schema
from ..models import Booking, BookingCreate, BookingRead, Message, ReviewProcedureIn, ReviewRead


router = APIRouter(prefix="/procedures", tags=["procedures"])


@router.post(
    "/create-booking",
    response_model=BookingRead,
    status_code=201,
    responses={
        400: {"model": Message},
        404: {"model": Message},
        409: {"model": Message},
    },
)
def procedure_create_booking(payload: BookingCreate, session: SessionDep):
    # Процедура в БД создает запись и возвращает только id, объект дочитываем вторым шагом.
    booking_id = session.execute(
        text("SELECT fn_api_create_booking(:estate_id, :guest_id, :start_date, :end_date) AS booking_id"),
        {
            "estate_id": payload.estate_id,
            "guest_id": payload.guest_id,
            "start_date": payload.start_date,
            "end_date": payload.end_date,
        },
    ).scalar_one()
    commit_or_raise(session)

    booking = get_or_404(session, Booking, booking_id, "Booking was not created")
    return to_schema(BookingRead, booking)


@router.post(
    "/add-or-update-review",
    response_model=ReviewRead,
    responses={
        400: {"model": Message},
        409: {"model": Message},
    },
)
def procedure_add_or_update_review(payload: ReviewProcedureIn, session: SessionDep):
    # Здесь 400 документирован явно, чтобы Swagger не показывал "Undocumented" на бизнес-ошибках.
    row = session.execute(
        text(
            """
            SELECT *
            FROM fn_api_add_or_update_review(:booking_id, :rating, :comment)
            """
        ),
        {
            "booking_id": payload.booking_id,
            "rating": payload.rating,
            "comment": payload.comment,
        },
    ).mappings().one()
    commit_or_raise(session)

    return to_schema(ReviewRead, dict(row))
