from __future__ import annotations

import json
import os
from pathlib import Path
from urllib import error, request

import psycopg


BASE_URL = os.environ.get("LAB6_API_BASE", "http://127.0.0.1:8006")
DB_DSN = os.environ.get("LAB6_DB_CLEANUP_DSN", "postgresql://admin:admin@localhost:5434/lab4")
ROOT = Path(__file__).resolve().parent
RESULTS_FILE = ROOT / "api_results.json"


def call(method: str, path: str, payload: dict | None = None, expect_json: bool = True):
    url = f"{BASE_URL}{path}"
    data = None
    headers = {}

    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = request.Request(url, data=data, method=method, headers=headers)
    try:
        with request.urlopen(req) as response:
            raw = response.read()
            text = raw.decode("utf-8")
            if not expect_json:
                return {"status": response.status, "body": text}
            return json.loads(text)
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8")
        raise RuntimeError(f"{method} {path} failed: {exc.code} {body}") from exc


def cleanup() -> None:
    with psycopg.connect(DB_DSN, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id
                FROM estate
                WHERE name = 'Lab6 API Estate'
                """
            )
            estate_ids = [row[0] for row in cur.fetchall()]

            cur.execute(
                """
                SELECT id
                FROM bookings
                WHERE (estate_id = 701 AND start_date IN (DATE '2026-07-12', DATE '2026-07-24'))
                   OR estate_id = ANY(%s)
                """,
                (estate_ids or [0],),
            )
            booking_ids = [row[0] for row in cur.fetchall()]

            if booking_ids:
                cur.execute("DELETE FROM booking_audit WHERE booking_id = ANY(%s)", (booking_ids,))
                cur.execute("DELETE FROM reviews WHERE booking_id = ANY(%s)", (booking_ids,))
                cur.execute("DELETE FROM bookings WHERE id = ANY(%s)", (booking_ids,))

            if estate_ids:
                cur.execute("DELETE FROM estate WHERE id = ANY(%s)", (estate_ids,))

            cur.execute(
                "DELETE FROM users WHERE email = 'lab6_api_user@example.com'"
            )


def main() -> None:
    cleanup()
    result: dict[str, object] = {}

    result["health"] = call("GET", "/health")
    result["users_list"] = call("GET", "/users?page=1&limit=2&sort=id&order=asc")

    created_user = call(
        "POST",
        "/users",
        {
            "name": "Lab6 API User",
            "email": "lab6_api_user@example.com",
            "password_hash": "hash_lab6_api_user",
            "phone": "+79029999991",
            "role": "guest",
        },
    )
    result["user_created"] = created_user
    result["user_updated"] = call(
        "PUT",
        f"/users/{created_user['id']}",
        {
            "name": "Lab6 API User Updated",
            "role": "both",
        },
    )

    result["estates_list"] = call("GET", "/estates?host_id=601&limit=2")
    created_estate = call(
        "POST",
        "/estates",
        {
            "host_id": 601,
            "name": "Lab6 API Estate",
            "description": "Estate created during API smoke test",
            "location": "Yaroslavl",
            "price_per_night": 5100,
            "available_from": "2026-08-01",
            "available_to": "2026-12-31",
        },
    )
    result["estate_created"] = created_estate
    result["estate_updated"] = call(
        "PUT",
        f"/estates/{created_estate['id']}",
        {
            "location": "Kostroma",
        },
    )

    result["booking_get"] = call("GET", "/bookings/801")
    created_booking = call(
        "POST",
        "/bookings",
        {
            "estate_id": 701,
            "guest_id": 603,
            "start_date": "2026-07-10",
            "end_date": "2026-07-12",
        },
    )
    result["booking_created"] = created_booking
    result["booking_updated"] = call(
        "PUT",
        f"/bookings/{created_booking['id']}",
        {
            "start_date": "2026-07-12",
            "end_date": "2026-07-14",
        },
    )

    result["view_booking_details"] = call("GET", "/views/booking-details?estate_id=701&limit=2")
    result["function_amount"] = call(
        "GET",
        "/functions/calc-booking-amount?estate_id=701&start_date=2026-07-20&end_date=2026-07-23",
    )
    result["function_active"] = call("GET", "/functions/is-guest-active?guest_id=602&days=365")

    procedure_booking = call(
        "POST",
        "/procedures/create-booking",
        {
            "estate_id": 701,
            "guest_id": 602,
            "start_date": "2026-07-24",
            "end_date": "2026-07-27",
        },
    )
    result["procedure_booking"] = procedure_booking
    result["procedure_review"] = call(
        "POST",
        "/procedures/add-or-update-review",
        {
            "booking_id": procedure_booking["id"],
            "rating": 5,
            "comment": "Procedure review from smoke test",
        },
    )

    result["view_host_revenue"] = call("GET", "/views/host-revenue-stats?filter=Lab6&limit=3")
    result["report_top_hosts"] = call("GET", "/reports/top-hosts?limit=3")
    result["report_locations"] = call("GET", "/reports/revenue-by-location")
    result["docs_status"] = call("GET", "/docs", expect_json=False)["status"]
    result["openapi_title"] = call("GET", "/openapi.json")["info"]["title"]

    result["procedure_booking_deleted"] = call("DELETE", f"/bookings/{procedure_booking['id']}")
    result["booking_deleted"] = call("DELETE", f"/bookings/{created_booking['id']}")
    result["estate_deleted"] = call("DELETE", f"/estates/{created_estate['id']}")
    result["user_deleted"] = call("DELETE", f"/users/{created_user['id']}")

    RESULTS_FILE.write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(RESULTS_FILE)


if __name__ == "__main__":
    main()
