from __future__ import annotations

import os
import threading
import time
from contextlib import closing
from pathlib import Path
from typing import Any

import psycopg


ROOT = Path(__file__).resolve().parent
RESULTS_FILE = ROOT / "concurrency_results.txt"
DSN = os.environ.get(
    "LAB5_DATABASE_URL",
    "postgresql://admin:admin@localhost:5434/lab4",
)


def execute(sql: str, params: tuple[Any, ...] = ()) -> None:
    with closing(psycopg.connect(DSN, autocommit=True)) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)


def fetch_one(sql: str, params: tuple[Any, ...] = ()) -> tuple[Any, ...]:
    with closing(psycopg.connect(DSN, autocommit=True)) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
            if row is None:
                raise RuntimeError(f"No rows returned for query: {sql}")
            return row


def reset_for_blocking() -> None:
    # Возвращаем объект в базовое состояние перед экспериментом с блокировкой.
    execute("UPDATE estate SET price_per_night = 4500.00 WHERE id = 201")


def reset_for_write_skew() -> None:
    # Убираем августовские брони для объекта 201, чтобы каждый прогон начинался одинаково.
    booking_ids = fetch_one(
        """
        SELECT COALESCE(array_agg(id), ARRAY[]::int[])
        FROM bookings
        WHERE estate_id = 201
          AND start_date >= DATE '2026-08-01'
          AND start_date < DATE '2026-09-01'
        """
    )[0]
    if booking_ids:
        execute("DELETE FROM booking_audit WHERE booking_id = ANY(%s)", (booking_ids,))
        execute("DELETE FROM reviews WHERE booking_id = ANY(%s)", (booking_ids,))
        execute("DELETE FROM bookings WHERE id = ANY(%s)", (booking_ids,))


def blocking_demo() -> dict[str, Any]:
    reset_for_blocking()
    ready = threading.Event()
    result: dict[str, Any] = {}

    def tx1() -> None:
        with closing(psycopg.connect(DSN, autocommit=True)) as conn:
            with conn.cursor() as cur:
                cur.execute("BEGIN")
                cur.execute(
                    "UPDATE estate SET price_per_night = price_per_night + 100 WHERE id = 201"
                )
                ready.set()
                time.sleep(4)
                cur.execute("COMMIT")

    def tx2() -> None:
        ready.wait()
        with closing(psycopg.connect(DSN, autocommit=True)) as conn:
            with conn.cursor() as cur:
                start = time.perf_counter()
                cur.execute("BEGIN")
                cur.execute(
                    "UPDATE estate SET price_per_night = price_per_night + 200 WHERE id = 201"
                )
                cur.execute("COMMIT")
                result["blocked_seconds"] = round(time.perf_counter() - start, 3)

    thread_one = threading.Thread(target=tx1, name="blocking-tx1")
    thread_two = threading.Thread(target=tx2, name="blocking-tx2")
    thread_one.start()
    thread_two.start()
    thread_one.join()
    thread_two.join()

    final_price = fetch_one("SELECT price_per_night FROM estate WHERE id = 201")[0]
    result["final_price"] = float(final_price)
    return result


def short_error(message: str) -> str:
    return message.splitlines()[0].strip()


def format_tx_line(tx: dict[str, Any]) -> str:
    if tx["status"] == "committed":
        return f"- {tx['name']}: COMMIT, увидела {tx['seen_count']} подходящих броней"
    return (
        f"- {tx['name']}: FAIL ({tx['error_type']}), увидела {tx['seen_count']} подходящих броней, "
        f"сообщение: {short_error(tx['error_message'])}"
    )


def isolation_conclusion(result: dict[str, Any]) -> tuple[str, str]:
    if result["final_count"] == 1:
        return (
            "PASS",
            "Бизнес-правило сохранено: в августе осталась только одна новая бронь.",
        )
    return (
        "FAIL",
        "Бизнес-правило нарушено: обе транзакции смогли добавить бронь независимо друг от друга.",
    )


def write_skew_demo(isolation_level: str) -> dict[str, Any]:
    reset_for_write_skew()
    barrier = threading.Barrier(2)
    results: list[dict[str, Any]] = []
    lock = threading.Lock()

    def worker(name: str, guest_id: int, start_date: str, end_date: str) -> None:
        outcome: dict[str, Any] = {
            "name": name,
            "guest_id": guest_id,
            "status": "committed",
            "seen_count": None,
        }
        try:
            with closing(psycopg.connect(DSN, autocommit=True)) as conn:
                with conn.cursor() as cur:
                    cur.execute(f"BEGIN ISOLATION LEVEL {isolation_level}")
                    cur.execute(
                        """
                        SELECT COUNT(*)
                        FROM bookings
                        WHERE estate_id = 201
                          AND start_date >= DATE '2026-08-01'
                          AND start_date < DATE '2026-09-01'
                        """
                    )
                    outcome["seen_count"] = cur.fetchone()[0]
                    barrier.wait(timeout=5)
                    if outcome["seen_count"] == 0:
                        cur.execute(
                            """
                            INSERT INTO bookings (
                                estate_id,
                                guest_id,
                                start_date,
                                end_date,
                                total_price
                            )
                            VALUES (
                                201,
                                %s,
                                %s,
                                %s,
                                fn_calc_booking_amount(201, %s::date, %s::date)
                            )
                            """,
                            (guest_id, start_date, end_date, start_date, end_date),
                        )
                    cur.execute("COMMIT")
        except Exception as exc:
            outcome["status"] = "failed"
            outcome["error_type"] = exc.__class__.__name__
            outcome["error_message"] = str(exc)
        with lock:
            results.append(outcome)

    thread_one = threading.Thread(
        target=worker,
        args=("T1", 102, "2026-08-10", "2026-08-12"),
        name=f"{isolation_level}-t1",
    )
    thread_two = threading.Thread(
        target=worker,
        args=("T2", 103, "2026-08-15", "2026-08-17"),
        name=f"{isolation_level}-t2",
    )
    thread_one.start()
    thread_two.start()
    thread_one.join()
    thread_two.join()

    final_count, guest_ids = fetch_one(
        """
        SELECT COUNT(*), COALESCE(array_agg(guest_id ORDER BY guest_id), ARRAY[]::int[])
        FROM bookings
        WHERE estate_id = 201
          AND start_date >= DATE '2026-08-01'
          AND start_date < DATE '2026-09-01'
        """
    )

    return {
        "isolation_level": isolation_level,
        "transactions": sorted(results, key=lambda item: item["name"]),
        "final_count": final_count,
        "guest_ids": list(guest_ids),
    }


def render_report() -> str:
    lines: list[str] = []
    lines.append("ЛР5: параллельное выполнение и уровни изоляции")
    lines.append(f"Подключение: {DSN}")
    lines.append("")

    block = blocking_demo()
    lines.append("[Эксперимент 1] Блокировка одной строки")
    lines.append("Сценарий: T1 обновляет объект estate.id=201 и держит транзакцию открытой 4 секунды.")
    lines.append("T2 пытается обновить ту же строку, пока T1 еще не завершилась.")
    lines.append(f"Ожидание T2: {block['blocked_seconds']} с")
    lines.append(f"Итоговая цена объекта: {block['final_price']:.2f}")
    lines.append(
        "Вывод: блокировка строки действительно возникла, вторая транзакция ждала освобождения ресурса."
    )
    lines.append("")

    lines.append("[Эксперимент 2] Сравнение уровней изоляции")
    lines.append(
        "Проверяем прикладное правило: для объекта 201 в августе должна сохраниться только одна новая бронь."
    )
    lines.append(
        "Обе транзакции сначала читают число броней, затем при необходимости пытаются вставить свою запись."
    )
    lines.append("")
    for isolation_level in ("READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE"):
        result = write_skew_demo(isolation_level)
        verdict, conclusion = isolation_conclusion(result)
        lines.append(f"{result['isolation_level']}")
        lines.append("-" * len(result["isolation_level"]))
        for tx in result["transactions"]:
            lines.append(format_tx_line(tx))
        lines.append(f"- Итоговое число августовских броней: {result['final_count']}")
        lines.append(f"- guest_id в итоговых бронях: {result['guest_ids']}")
        lines.append(f"- Результат проверки: {verdict}")
        lines.append(f"- Вывод: {conclusion}")
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def main() -> None:
    RESULTS_FILE.write_text(render_report(), encoding="utf-8")
    print(RESULTS_FILE)


if __name__ == "__main__":
    main()
