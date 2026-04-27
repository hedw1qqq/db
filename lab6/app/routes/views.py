from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Query

from ..db import SessionDep
from ..helpers import run_paged_view_query
from ..models import GenericPage, Order


router = APIRouter(prefix="/views", tags=["views"])


@router.get("/booking-details", response_model=GenericPage)
def view_booking_details(
    session: SessionDep,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=100),
    sort: str = "booking_id",
    order: Order = "asc",
    filter: str | None = None,
    estate_id: int | None = None,
    guest_id: int | None = None,
):
    # Представления читаем через raw SQL, потому что их структура уже зафиксирована на стороне БД.
    filters: list[str] = []
    params: dict[str, Any] = {}
    if estate_id is not None:
        filters.append("estate_id = :estate_id")
        params["estate_id"] = estate_id
    if guest_id is not None:
        filters.append("guest_id = :guest_id")
        params["guest_id"] = guest_id
    if filter:
        filters.append("(estate_name ILIKE :filter OR guest_name ILIKE :filter OR host_name ILIKE :filter)")
        params["filter"] = f"%{filter}%"

    return run_paged_view_query(
        session,
        "v_booking_details",
        {"booking_id", "start_date", "end_date", "total_price", "guest_name", "host_name", "estate_name"},
        sort,
        order,
        page,
        limit,
        filters,
        params,
    )


@router.get("/host-revenue-stats", response_model=GenericPage)
def view_host_revenue_stats(
    session: SessionDep,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=100),
    sort: str = "host_id",
    order: Order = "asc",
    filter: str | None = None,
):
    filters: list[str] = []
    params: dict[str, Any] = {}
    if filter:
        filters.append("host_name ILIKE :filter")
        params["filter"] = f"%{filter}%"

    return run_paged_view_query(
        session,
        "v_host_revenue_stats",
        {"host_id", "host_name", "revenue_total", "bookings_total"},
        sort,
        order,
        page,
        limit,
        filters,
        params,
    )


@router.get("/guest-activity-month", response_model=GenericPage)
def view_guest_activity_month(
    session: SessionDep,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=100),
    sort: str = "guest_id",
    order: Order = "asc",
    filter: str | None = None,
    guest_id: int | None = None,
):
    filters: list[str] = []
    params: dict[str, Any] = {}
    if guest_id is not None:
        filters.append("guest_id = :guest_id")
        params["guest_id"] = guest_id
    if filter:
        filters.append("guest_name ILIKE :filter")
        params["filter"] = f"%{filter}%"

    return run_paged_view_query(
        session,
        "v_guest_activity_month",
        {"guest_id", "guest_name", "month_start", "spent_total", "bookings_total"},
        sort,
        order,
        page,
        limit,
        filters,
        params,
    )
