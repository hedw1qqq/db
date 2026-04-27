
\pset pager off
\pset null '(null)'
\set ON_ERROR_STOP on

\echo ===========================
\echo LAB 5: TRANSACTION SCENARIOS
\echo ===========================

\ir 15_reset_helpers.sql

\echo
\echo [Scenario 1] Booking + review + audit
\echo -------------------------------------

CALL pr_lab5_reset_scenario1();

\echo
\echo 1.1 COMMIT
BEGIN;
-- Получаем id новой брони сразу в psql-переменную и используем его в следующих проверках.
SELECT fn_lab5_create_booking(201, 102, DATE '2026-07-01', DATE '2026-07-04') AS s1_commit_booking_id
\gset
CALL pr_add_or_update_review(:s1_commit_booking_id, 5, 'Scenario 1 commit review');
COMMIT;

\echo [Проверка 1.1] После COMMIT бронь, отзыв и аудит должны существовать
SELECT :s1_commit_booking_id AS s1_commit_booking_id;

\echo [Детали 1.1] Итоговая запись в представлении v_booking_details
SELECT booking_id, estate_id, guest_id, start_date, end_date, total_price, rating, comment
FROM v_booking_details
WHERE estate_id = 201
  AND start_date = DATE '2026-07-01';

\echo [Детали 1.1] Запись в booking_audit
SELECT booking_id, action_type, old_total_price, new_total_price
FROM booking_audit
WHERE booking_id = :s1_commit_booking_id
ORDER BY id;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v_booking_details
            WHERE booking_id = :s1_commit_booking_id
              AND rating = 5
        )
        AND EXISTS (
            SELECT 1
            FROM booking_audit
            WHERE booking_id = :s1_commit_booking_id
              AND action_type = 'INSERT'
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'Бронь сохранена, отзыв сохранен, аудит INSERT создан' AS explanation;

\echo
\echo 1.2 ROLLBACK after error
\set ON_ERROR_STOP off
BEGIN;
-- Здесь ошибка ожидаемая: проверяем, что после нее транзакция целиком откатывается.
\echo [Ожидаемая ошибка 1.2] rating=7 нарушает ограничение процедуры отзыва
DO $$
DECLARE
    v_booking_id INT;
BEGIN
    CALL pr_create_booking(201, 103, DATE '2026-07-05', DATE '2026-07-08', v_booking_id);
    CALL pr_add_or_update_review(v_booking_id, 7, 'Scenario 1 invalid review');
END;
$$;
ROLLBACK;
\set ON_ERROR_STOP on

\echo [Проверка 1.2] После ROLLBACK брони на эту дату остаться не должно
SELECT COUNT(*) AS s1_rollback_booking_count
FROM bookings
WHERE estate_id = 201
  AND start_date = DATE '2026-07-05';

SELECT
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    'После полного отката бронирование не сохранилось' AS explanation
FROM bookings
WHERE estate_id = 201
  AND start_date = DATE '2026-07-05';

\echo
\echo 1.3 SAVEPOINT + partial rollback
BEGIN;
SELECT fn_lab5_create_booking(201, 103, DATE '2026-07-08', DATE '2026-07-10') AS s1_savepoint_booking_id
\gset
-- SAVEPOINT позволяет откатить только невалидный отзыв, а не все бронирование.
SAVEPOINT review_sp;
\set ON_ERROR_STOP off
\echo [Ожидаемая ошибка 1.3] Невалидный отзыв откатываем только до SAVEPOINT
CALL pr_add_or_update_review(:s1_savepoint_booking_id, 9, 'Scenario 1 wrong rating');
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT review_sp;
CALL pr_add_or_update_review(:s1_savepoint_booking_id, 4, 'Scenario 1 fixed review after rollback to savepoint');
COMMIT;

\echo [Проверка 1.3] Бронь должна сохраниться, отзыв должен быть исправлен на rating=4
SELECT booking_id, start_date, end_date, total_price, rating, comment
FROM v_booking_details
WHERE booking_id = :s1_savepoint_booking_id;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v_booking_details
            WHERE booking_id = :s1_savepoint_booking_id
              AND rating = 4
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'После отката к SAVEPOINT бронь сохранена, отзыв записан со второй попытки' AS explanation;

\echo
\echo [Scenario 2] New host + estate + first booking
\echo ----------------------------------------------

CALL pr_lab5_reset_scenario2();

\echo
\echo 2.1 COMMIT
BEGIN;
INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Lab5 S2 Commit Host', 'lab5_s2_commit_host@example.com', 'hash_lab5_s2_commit_host', '+79010000111', 'host')
RETURNING id AS s2_host_id
\gset

INSERT INTO estate (
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to
)
VALUES (
    :s2_host_id,
    'Lab5 S2 Commit Estate',
    'First estate for a new host',
    'Tula',
    6100.00,
    DATE '2026-09-01',
    DATE '2026-12-31'
)
RETURNING id AS s2_estate_id
\gset

INSERT INTO bookings (estate_id, guest_id, start_date, end_date, total_price)
VALUES (
    :s2_estate_id,
    102,
    DATE '2026-09-10',
    DATE '2026-09-13',
    fn_calc_booking_amount(:s2_estate_id, DATE '2026-09-10', DATE '2026-09-13')
);
COMMIT;

\echo [Проверка 2.1] После COMMIT должны существовать хост, объект и первое бронирование
SELECT u.id AS host_id, u.email, e.id AS estate_id, e.location
FROM users u
JOIN estate e ON e.host_id = u.id
WHERE u.email = 'lab5_s2_commit_host@example.com';

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM users
            WHERE email = 'lab5_s2_commit_host@example.com'
        )
        AND EXISTS (
            SELECT 1
            FROM estate
            WHERE id = :s2_estate_id
        )
        AND EXISTS (
            SELECT 1
            FROM bookings
            WHERE estate_id = :s2_estate_id
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'Новый хост, объект и бронирование успешно зафиксированы' AS explanation;

\echo
\echo 2.2 ROLLBACK after error
\set ON_ERROR_STOP off
BEGIN;
INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Lab5 S2 Rollback Host', 'lab5_s2_rollback_host@example.com', 'hash_lab5_s2_rollback_host', '+79010000112', 'host')
RETURNING id AS s2_bad_host_id
\gset

\echo [Ожидаемая ошибка 2.2] Объект с перевернутым диапазоном дат должен вызвать ROLLBACK
INSERT INTO estate (
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to
)
VALUES (
    :s2_bad_host_id,
    'Lab5 S2 Broken Estate',
    'This row must fail because the dates are invalid',
    'Yaroslavl',
    5000.00,
    DATE '2026-12-31',
    DATE '2026-09-01'
);
ROLLBACK;
\set ON_ERROR_STOP on

\echo [Проверка 2.2] После ROLLBACK новый хост не должен сохраниться
SELECT COUNT(*) AS s2_rollback_host_count
FROM users
WHERE email = 'lab5_s2_rollback_host@example.com';

SELECT
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    'После полного отката пользователь не сохранился' AS explanation
FROM users
WHERE email = 'lab5_s2_rollback_host@example.com';

\echo
\echo 2.3 SAVEPOINT + partial rollback
BEGIN;
INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Lab5 S2 Savepoint Host', 'lab5_s2_savepoint_host@example.com', 'hash_lab5_s2_savepoint_host', '+79010000113', 'host')
RETURNING id AS s2_save_host_id
\gset

SAVEPOINT estate_sp;
\set ON_ERROR_STOP off
-- Намеренно вставляем некорректные даты, чтобы затем откатиться только к savepoint.
\echo [Ожидаемая ошибка 2.3] Некорректный объект откатываем только до SAVEPOINT
INSERT INTO estate (
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to
)
VALUES (
    :s2_save_host_id,
    'Lab5 S2 Savepoint Estate',
    'Invalid dates before rollback to savepoint',
    'Smolensk',
    5200.00,
    DATE '2026-12-31',
    DATE '2026-09-01'
);
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT estate_sp;

INSERT INTO estate (
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to
)
VALUES (
    :s2_save_host_id,
    'Lab5 S2 Savepoint Estate',
    'Corrected estate after rollback to savepoint',
    'Smolensk',
    5200.00,
    DATE '2026-09-01',
    DATE '2026-12-31'
)
RETURNING id AS s2_save_estate_id
\gset

INSERT INTO bookings (estate_id, guest_id, start_date, end_date, total_price)
VALUES (
    :s2_save_estate_id,
    103,
    DATE '2026-09-20',
    DATE '2026-09-23',
    fn_calc_booking_amount(:s2_save_estate_id, DATE '2026-09-20', DATE '2026-09-23')
);
COMMIT;

\echo [Проверка 2.3] После SAVEPOINT должны сохраниться хост, исправленный объект и бронь
SELECT u.id AS host_id, e.id AS estate_id, b.id AS booking_id
FROM users u
JOIN estate e ON e.host_id = u.id
JOIN bookings b ON b.estate_id = e.id
WHERE u.email = 'lab5_s2_savepoint_host@example.com';

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM users
            WHERE id = :s2_save_host_id
        )
        AND EXISTS (
            SELECT 1
            FROM estate
            WHERE id = :s2_save_estate_id
        )
        AND EXISTS (
            SELECT 1
            FROM bookings
            WHERE estate_id = :s2_save_estate_id
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'После частичного отката операция завершилась успешно' AS explanation;

\echo
\echo [Scenario 3] Reschedule booking + review update
\echo -----------------------------------------------

CALL pr_lab5_reset_scenario3();

\echo
\echo 3.1 COMMIT
BEGIN;
UPDATE bookings
SET start_date = DATE '2026-07-13',
    end_date = DATE '2026-07-15',
    total_price = fn_calc_booking_amount(202, DATE '2026-07-13', DATE '2026-07-15')
WHERE id = 301;
CALL pr_add_or_update_review(301, 5, 'Scenario 3 commit review');
COMMIT;

\echo [Проверка 3.1] После COMMIT бронирование должно быть перенесено, отзыв и аудит обновлены
SELECT booking_id, start_date, end_date, total_price, rating, comment
FROM v_booking_details
WHERE booking_id = 301;

\echo [Детали 3.1] Запись в booking_audit
SELECT booking_id, action_type, old_total_price, new_total_price
FROM booking_audit
WHERE booking_id = 301
ORDER BY id;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v_booking_details
            WHERE booking_id = 301
              AND start_date = DATE '2026-07-13'
              AND end_date = DATE '2026-07-15'
              AND rating = 5
        )
        AND EXISTS (
            SELECT 1
            FROM booking_audit
            WHERE booking_id = 301
              AND action_type = 'UPDATE'
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'Перенос брони и обновление отзыва успешно зафиксированы' AS explanation;

\echo
\echo 3.2 ROLLBACK after error
\set ON_ERROR_STOP off
BEGIN;
\echo [Ожидаемая ошибка 3.2] Попытка переноса в занятый интервал должна быть отменена
UPDATE bookings
SET start_date = DATE '2026-07-18',
    end_date = DATE '2026-07-20',
    total_price = fn_calc_booking_amount(202, DATE '2026-07-18', DATE '2026-07-20')
WHERE id = 301;
CALL pr_add_or_update_review(301, 2, 'Scenario 3 rollback review');
ROLLBACK;
\set ON_ERROR_STOP on

\echo [Проверка 3.2] После ROLLBACK состояние брони должно остаться как после шага 3.1
SELECT booking_id, start_date, end_date, total_price, rating, comment
FROM v_booking_details
WHERE booking_id = 301;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v_booking_details
            WHERE booking_id = 301
              AND start_date = DATE '2026-07-13'
              AND end_date = DATE '2026-07-15'
              AND rating = 5
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'После полного отката состояние не изменилось' AS explanation;

\echo
\echo 3.3 SAVEPOINT + partial rollback
BEGIN;
SAVEPOINT move_sp;
\set ON_ERROR_STOP off
-- Здесь конфликт по датам ожидаем и служит демонстрацией частичного отката.
\echo [Ожидаемая ошибка 3.3] Конфликтный перенос откатываем только до SAVEPOINT
UPDATE bookings
SET start_date = DATE '2026-07-18',
    end_date = DATE '2026-07-20',
    total_price = fn_calc_booking_amount(202, DATE '2026-07-18', DATE '2026-07-20')
WHERE id = 301;
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT move_sp;

UPDATE bookings
SET start_date = DATE '2026-07-21',
    end_date = DATE '2026-07-23',
    total_price = fn_calc_booking_amount(202, DATE '2026-07-21', DATE '2026-07-23')
WHERE id = 301;
CALL pr_add_or_update_review(301, 4, 'Scenario 3 review after rollback to savepoint');
COMMIT;

\echo [Проверка 3.3] После SAVEPOINT бронь должна быть перенесена на новый валидный интервал
SELECT booking_id, start_date, end_date, total_price, rating, comment
FROM v_booking_details
WHERE booking_id = 301;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v_booking_details
            WHERE booking_id = 301
              AND start_date = DATE '2026-07-21'
              AND end_date = DATE '2026-07-23'
              AND rating = 4
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    'После отката к SAVEPOINT выполнен корректный перенос и обновлен отзыв' AS explanation;
