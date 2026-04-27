from __future__ import annotations

from fastapi import APIRouter, Query
from sqlalchemy import text

from ..db import SessionDep
from ..helpers import serialize_mapping


router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/top-hosts")
def report_top_hosts(session: SessionDep, limit: int = Query(default=5, ge=1, le=20)):
    # Отчеты оставлены на raw SQL: так ближе к формулировке лабораторной и проще читать агрегации.
    rows = session.execute(
        text(
            """
            SELECT host_id, host_name, revenue_total, bookings_total
            FROM v_host_revenue_stats
            ORDER BY revenue_total DESC, host_id ASC
            LIMIT :limit
            """
        ),
        {"limit": limit},
    ).mappings().all()
    return [serialize_mapping(dict(row)) for row in rows]


@router.get("/revenue-by-location")
def report_revenue_by_location(session: SessionDep):
    rows = session.execute(
        text(
            """
            SELECT
                e.location,
                COUNT(b.id) AS bookings_total,
                COALESCE(SUM(b.total_price), 0) AS revenue_total
            FROM estate e
            LEFT JOIN bookings b ON b.estate_id = e.id
            GROUP BY e.location
            ORDER BY revenue_total DESC, e.location ASC
            """
        )
    ).mappings().all()
    return [serialize_mapping(dict(row)) for row in rows]


@router.get("/guest-spending")
def report_guest_spending(session: SessionDep):
    rows = session.execute(
        text(
            """
            SELECT
                u.id AS guest_id,
                u.name AS guest_name,
                COUNT(b.id) AS bookings_total,
                COALESCE(SUM(b.total_price), 0) AS spent_total
            FROM users u
            LEFT JOIN bookings b ON b.guest_id = u.id
            WHERE u.role IN ('guest', 'both')
            GROUP BY u.id, u.name
            ORDER BY spent_total DESC, u.id ASC
            """
        )
    ).mappings().all()
    return [serialize_mapping(dict(row)) for row in rows]
