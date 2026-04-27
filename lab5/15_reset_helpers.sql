-- Здесь собраны короткие helper-процедуры, чтобы основной сценарный файл не тонул в служебной подготовке.
CREATE OR REPLACE PROCEDURE pr_lab5_reset_scenario1()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Чистим только записи сценария 1, не трогая остальной датасет.
    DELETE FROM booking_audit
    WHERE booking_id IN (
        SELECT id
        FROM bookings
        WHERE estate_id = 201
          AND start_date BETWEEN DATE '2026-07-01' AND DATE '2026-08-31'
    );

    DELETE FROM reviews
    WHERE booking_id IN (
        SELECT id
        FROM bookings
        WHERE estate_id = 201
          AND start_date BETWEEN DATE '2026-07-01' AND DATE '2026-08-31'
    );

    DELETE FROM bookings
    WHERE estate_id = 201
      AND start_date BETWEEN DATE '2026-07-01' AND DATE '2026-08-31';
END;
$$;


CREATE OR REPLACE FUNCTION fn_lab5_create_booking(
    p_estate_id INT,
    p_guest_id INT,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_booking_id INT;
BEGIN
    -- Обертка над процедурой из ЛР3: удобно получать id сразу в psql-переменную через \gset.
    CALL pr_create_booking(p_estate_id, p_guest_id, p_start_date, p_end_date, v_booking_id);
    RETURN v_booking_id;
END;
$$;


CREATE OR REPLACE PROCEDURE pr_lab5_reset_scenario2()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Сценарий 2 оставляет следы сразу в users, estate и bookings, поэтому чистим их сверху вниз.
    DELETE FROM booking_audit
    WHERE booking_id IN (
        SELECT b.id
        FROM bookings b
        JOIN estate e ON e.id = b.estate_id
        WHERE e.name LIKE 'Lab5 S2%'
    );

    DELETE FROM reviews
    WHERE booking_id IN (
        SELECT b.id
        FROM bookings b
        JOIN estate e ON e.id = b.estate_id
        WHERE e.name LIKE 'Lab5 S2%'
    );

    DELETE FROM bookings
    WHERE estate_id IN (
        SELECT id
        FROM estate
        WHERE name LIKE 'Lab5 S2%'
    );

    DELETE FROM estate
    WHERE name LIKE 'Lab5 S2%';

    DELETE FROM users
    WHERE email LIKE 'lab5_s2_%';
END;
$$;


CREATE OR REPLACE PROCEDURE pr_lab5_reset_scenario3()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Возвращаем бронирование 301 в базовое состояние перед проверкой COMMIT/ROLLBACK/SAVEPOINT.
    UPDATE bookings
    SET start_date = DATE '2026-07-10',
        end_date = DATE '2026-07-12',
        total_price = fn_calc_booking_amount(202, DATE '2026-07-10', DATE '2026-07-12')
    WHERE id = 301;

    CALL pr_add_or_update_review(301, 4, 'Base review for scenario 3');

    DELETE FROM booking_audit
    WHERE booking_id = 301;
END;
$$;
