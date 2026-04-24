\set ON_ERROR_STOP on
\pset pager off
\timing on

\echo =============================
\echo ЛР4: исследование индексов
\echo =============================

\echo
\echo [Сводка по объему данных]
SELECT 'users' AS table_name, COUNT(*) AS rows_count FROM users
UNION ALL
SELECT 'estate', COUNT(*) FROM estate
UNION ALL
SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews
ORDER BY table_name;

\echo
\echo [Очистка дополнительных индексов]
DROP INDEX IF EXISTS idx_lab4_bookings_estate_created;
DROP INDEX IF EXISTS idx_lab4_bookings_created_desc;
DROP INDEX IF EXISTS idx_lab4_bookings_created_guest;
DROP INDEX IF EXISTS idx_lab4_bookings_guest_created;
DROP INDEX IF EXISTS idx_lab4_estate_description_trgm;
DROP INDEX IF EXISTS idx_lab4_estate_location;
DROP INDEX IF EXISTS idx_lab4_bookings_estate_created_join;
DROP INDEX IF EXISTS idx_lab4_bookings_created_wide;

\echo
\echo [Сценарий 1] Сложный фильтр
\echo Гипотеза: составной B-tree индекс по (estate_id, created_at) сократит чтение для условия "точное совпадение + диапазон".
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.guest_id,
    b.total_price,
    b.created_at
FROM bookings b
WHERE b.estate_id = 12020
  AND b.created_at >= TIMESTAMP '2024-04-01'
  AND b.created_at < TIMESTAMP '2024-08-01'
  AND b.total_price BETWEEN 30000 AND 35000;

CREATE INDEX idx_lab4_bookings_estate_created
    ON bookings (estate_id, created_at);

ANALYZE bookings;

SELECT
    'idx_lab4_bookings_estate_created' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_bookings_estate_created')) AS index_size;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.guest_id,
    b.total_price,
    b.created_at
FROM bookings b
WHERE b.estate_id = 12020
  AND b.created_at >= TIMESTAMP '2024-04-01'
  AND b.created_at < TIMESTAMP '2024-08-01'
  AND b.total_price BETWEEN 30000 AND 35000;

DROP INDEX idx_lab4_bookings_estate_created;

\echo
\echo [Сценарий 2] ORDER BY + LIMIT
\echo Гипотеза: индекс по created_at DESC позволит выбрать верхние строки без полного сканирования и сортировки.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.estate_id,
    b.guest_id,
    b.created_at
FROM bookings b
WHERE b.created_at >= TIMESTAMP '2024-07-01'
ORDER BY b.created_at DESC
LIMIT 50;

CREATE INDEX idx_lab4_bookings_created_desc
    ON bookings (created_at DESC);

ANALYZE bookings;

SELECT
    'idx_lab4_bookings_created_desc' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_bookings_created_desc')) AS index_size;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.estate_id,
    b.guest_id,
    b.created_at
FROM bookings b
WHERE b.created_at >= TIMESTAMP '2024-07-01'
ORDER BY b.created_at DESC
LIMIT 50;

DROP INDEX idx_lab4_bookings_created_desc;

\echo
\echo [Сценарий 3] Альтернативные варианты индексирования
\echo Гипотеза: порядок полей в составном индексе критичен; (guest_id, created_at) лучше, чем (created_at, guest_id).
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.estate_id,
    b.created_at,
    b.total_price
FROM bookings b
WHERE b.guest_id = 24567
  AND b.created_at >= TIMESTAMP '2024-03-01'
  AND b.created_at < TIMESTAMP '2024-10-01';

CREATE INDEX idx_lab4_bookings_created_guest
    ON bookings (created_at, guest_id);

ANALYZE bookings;

SELECT
    'idx_lab4_bookings_created_guest' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_bookings_created_guest')) AS index_size;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.estate_id,
    b.created_at,
    b.total_price
FROM bookings b
WHERE b.guest_id = 24567
  AND b.created_at >= TIMESTAMP '2024-03-01'
  AND b.created_at < TIMESTAMP '2024-10-01';

DROP INDEX idx_lab4_bookings_created_guest;

CREATE INDEX idx_lab4_bookings_guest_created
    ON bookings (guest_id, created_at);

ANALYZE bookings;

SELECT
    'idx_lab4_bookings_guest_created' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_bookings_guest_created')) AS index_size;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    b.estate_id,
    b.created_at,
    b.total_price
FROM bookings b
WHERE b.guest_id = 24567
  AND b.created_at >= TIMESTAMP '2024-03-01'
  AND b.created_at < TIMESTAMP '2024-10-01';

DROP INDEX idx_lab4_bookings_guest_created;

\echo
\echo [Сценарий 4] Текстовый поиск
\echo Гипотеза: GIN + pg_trgm ускорит поиск по подстроке в description.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.id,
    e.name,
    e.location
FROM estate e
WHERE e.description ILIKE '%панорамный вид на море%';

CREATE INDEX idx_lab4_estate_description_trgm
    ON estate
    USING GIN (description gin_trgm_ops);

ANALYZE estate;

SELECT
    'idx_lab4_estate_description_trgm' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_estate_description_trgm')) AS index_size;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.id,
    e.name,
    e.location
FROM estate e
WHERE e.description ILIKE '%панорамный вид на море%';

DROP INDEX idx_lab4_estate_description_trgm;

\echo
\echo [Сценарий 5] JOIN нескольких таблиц
\echo Гипотеза: для небольшого набора объектов индекс bookings(estate_id, created_at) переведет соединение в Nested Loop с точечным доступом по броням.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    e.name AS estate_name,
    e.location,
    u.name AS guest_name,
    b.total_price,
    b.created_at
FROM estate e
JOIN bookings b
  ON b.estate_id = e.id
JOIN users u
  ON u.id = b.guest_id
WHERE e.location = 'Казань'
  AND e.id BETWEEN 12000 AND 12100
  AND b.created_at >= TIMESTAMP '2024-05-01'
  AND b.created_at < TIMESTAMP '2024-09-01'
  AND b.total_price >= 18000;

CREATE INDEX idx_lab4_bookings_estate_created_join
    ON bookings (estate_id, created_at);

ANALYZE bookings;

SELECT
    'idx_lab4_bookings_estate_created_join' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_bookings_estate_created_join'));

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.id,
    e.name AS estate_name,
    e.location,
    u.name AS guest_name,
    b.total_price,
    b.created_at
FROM estate e
JOIN bookings b
  ON b.estate_id = e.id
JOIN users u
  ON u.id = b.guest_id
WHERE e.location = 'Казань'
  AND e.id BETWEEN 12000 AND 12100
  AND b.created_at >= TIMESTAMP '2024-05-01'
  AND b.created_at < TIMESTAMP '2024-09-01'
  AND b.total_price >= 18000;

DROP INDEX idx_lab4_bookings_estate_created_join;

\echo
\echo [Сценарий 6] Негативный сценарий
\echo Гипотеза: при выборе почти всей таблицы индекс по created_at не даст заметной пользы, и планировщик сохранит Seq Scan.
EXPLAIN (ANALYZE, BUFFERS)
SELECT AVG(b.total_price)
FROM bookings b
WHERE b.created_at >= TIMESTAMP '2024-01-01';

CREATE INDEX idx_lab4_bookings_created_wide
    ON bookings (created_at);

ANALYZE bookings;

SELECT
    'idx_lab4_bookings_created_wide' AS index_name,
    pg_size_pretty(pg_relation_size('idx_lab4_bookings_created_wide')) AS index_size;

EXPLAIN (ANALYZE, BUFFERS)
SELECT AVG(b.total_price)
FROM bookings b
WHERE b.created_at >= TIMESTAMP '2024-01-01';

DROP INDEX idx_lab4_bookings_created_wide;

\echo
\echo [Дополнительное требование] Влияние индексов на INSERT/UPDATE
\echo Для чистоты измерения используем estate: без триггеров из ЛР3, но с индексами из сценариев 4 и 5.
DROP INDEX IF EXISTS idx_lab4_estate_description_trgm;
DROP INDEX IF EXISTS idx_lab4_estate_location;

\echo
\echo INSERT без дополнительных индексов
BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO estate (
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to,
    created_at
)
SELECT
    9 + (gs % 20000),
    'Тестовая вставка #' || gs,
    'Тестовое описание для измерения влияния индексов на операции вставки.',
    CASE gs % 4
        WHEN 0 THEN 'Москва'
        WHEN 1 THEN 'Казань'
        WHEN 2 THEN 'Сочи'
        ELSE 'Калининград'
    END,
    ROUND((5000 + (gs % 200))::numeric, 2),
    DATE '2025-01-01',
    DATE '2028-12-31',
    TIMESTAMP '2025-01-01 12:00:00'
FROM generate_series(1, 3000) AS gs;
ROLLBACK;

\echo
\echo UPDATE без дополнительных индексов
BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE estate
SET description = description || ' Сезонная акция включена.'
WHERE id BETWEEN 20000 AND 23000;
ROLLBACK;

CREATE INDEX idx_lab4_estate_location
    ON estate (location);

CREATE INDEX idx_lab4_estate_description_trgm
    ON estate
    USING GIN (description gin_trgm_ops);

ANALYZE estate;

\echo
\echo INSERT при наличии индексов
BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO estate (
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to,
    created_at
)
SELECT
    9 + (gs % 20000),
    'Тестовая вставка с индексами #' || gs,
    'Тестовое описание для измерения влияния индексов на операции вставки.',
    CASE gs % 4
        WHEN 0 THEN 'Москва'
        WHEN 1 THEN 'Казань'
        WHEN 2 THEN 'Сочи'
        ELSE 'Калининград'
    END,
    ROUND((5000 + (gs % 200))::numeric, 2),
    DATE '2025-01-01',
    DATE '2028-12-31',
    TIMESTAMP '2025-01-01 12:00:00'
FROM generate_series(1, 3000) AS gs;
ROLLBACK;

\echo
\echo UPDATE при наличии индексов
BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE estate
SET description = description || ' Сезонная акция включена.'
WHERE id BETWEEN 20000 AND 23000;
ROLLBACK;
