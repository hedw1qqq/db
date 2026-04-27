from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Query
from sqlalchemy import text

from ..db import SessionDep
from ..helpers import calculate_booking_amount


router = APIRouter(prefix="/functions", tags=["functions"])


@router.get("/calc-booking-amount")
def function_calc_booking_amount(
    session: SessionDep,
    estate_id: int,
    start_date: date,
    end_date: date,
):
    # HTTP-обертка над SQL-функцией из базы, чтобы ее можно было проверить из Swagger.
    amount = calculate_booking_amount(session, estate_id, start_date, end_date)
    return {"amount": amount}


@router.get("/is-guest-active")
def function_is_guest_active(
    session: SessionDep,
    guest_id: int,
    days: int = Query(default=90, ge=1),
):
    active = session.execute(
        text("SELECT fn_is_guest_active(:guest_id, :days) AS active"),
        {"guest_id": guest_id, "days": days},
    ).scalar_one()
    return {"active": bool(active)}
