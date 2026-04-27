

-- Большой сид для ЛР4: создаем объем данных, на котором уже виден эффект индексов.
SET synchronous_commit = OFF;

-- 20 000 дополнительных хостов.
INSERT INTO users (name, email, password_hash, phone, role)
SELECT
    'Хост #' || gs,
    'host_' || gs || '@example.com',
    'hash_host_' || gs,
    '+7911' || LPAD(gs::text, 7, '0'),
    'host'
FROM generate_series(1, 20000) AS gs;

-- 30 000 дополнительных гостей.
INSERT INTO users (name, email, password_hash, phone, role)
SELECT
    'Гость #' || gs,
    'guest_' || gs || '@example.com',
    'hash_guest_' || gs,
    '+7922' || LPAD(gs::text, 7, '0'),
    'guest'
FROM generate_series(1, 30000) AS gs;

-- 10 000 универсальных пользователей.
INSERT INTO users (name, email, password_hash, phone, role)
SELECT
    'Пользователь both #' || gs,
    'both_' || gs || '@example.com',
    'hash_both_' || gs,
    '+7933' || LPAD(gs::text, 7, '0'),
    'both'
FROM generate_series(1, 10000) AS gs;

-- 50 000 объектов недвижимости с повторяемыми паттернами для экспериментов.
-- Шаблоны в name/description/location сделаны повторяемыми, чтобы было что фильтровать в EXPLAIN.
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
    CASE
        WHEN gs % 5 = 0 THEN 50009 + (gs % 10000)
        ELSE 9 + (gs % 20000)
    END AS host_id,
    CASE gs % 6
        WHEN 0 THEN 'Лофт #' || gs
        WHEN 1 THEN 'Студия #' || gs
        WHEN 2 THEN 'Апартаменты #' || gs
        WHEN 3 THEN 'Дом #' || gs
        WHEN 4 THEN 'Квартира #' || gs
        ELSE 'Таунхаус #' || gs
    END AS name,
    CONCAT_WS(
        '. ',
        CASE gs % 8
            WHEN 0 THEN 'Просторное жилье рядом с историческим центром'
            WHEN 1 THEN 'Современное жилье с бесконтактным заселением'
            WHEN 2 THEN 'Тихая квартира для деловой поездки'
            WHEN 3 THEN 'Уютный вариант для семейного отдыха'
            WHEN 4 THEN 'Светлые апартаменты рядом с парком'
            WHEN 5 THEN 'Лофт с дизайнерским интерьером'
            WHEN 6 THEN 'Жилье для длительного проживания'
            ELSE 'Объект с быстрым доступом к транспорту'
        END,
        CASE
            WHEN gs % 20 = 0 THEN 'панорамный вид на море и большая терраса'
            WHEN gs % 20 = 1 THEN 'отдельная спальня и рабочее место'
            WHEN gs % 20 = 2 THEN 'уютный балкон и тихий двор'
            WHEN gs % 20 = 3 THEN 'камин и просторная гостиная'
            WHEN gs % 20 = 4 THEN 'бесконтактный заезд и теплый пол'
            WHEN gs % 20 = 5 THEN 'большая кухня и семейный формат'
            WHEN gs % 20 = 6 THEN 'вид на реку и панорамные окна'
            WHEN gs % 20 = 7 THEN 'терраса на крыше и зона отдыха'
            WHEN gs % 20 = 8 THEN 'стильный интерьер и библиотека'
            WHEN gs % 20 = 9 THEN 'тихий район и удобная парковка'
            WHEN gs % 20 = 10 THEN 'рабочее место и быстрый wifi'
            WHEN gs % 20 = 11 THEN 'свежий ремонт и светлая спальня'
            WHEN gs % 20 = 12 THEN 'два санузла и детская зона'
            WHEN gs % 20 = 13 THEN 'просторная кухня и кофемашина'
            WHEN gs % 20 = 14 THEN 'вид на город и высокий этаж'
            WHEN gs % 20 = 15 THEN 'семейный отдых и зеленый двор'
            WHEN gs % 20 = 16 THEN 'лофт-атмосфера и кирпичные стены'
            WHEN gs % 20 = 17 THEN 'быстрый интернет и удобный диван'
            WHEN gs % 20 = 18 THEN 'зона барбекю и закрытая территория'
            ELSE 'панорамный вид на море, терраса и вечерняя подсветка'
        END,
        'Быстрый Wi-Fi, полноценная кухня и стандартный набор для проживания'
    ) AS description,
    CASE gs % 10
        WHEN 0 THEN 'Москва'
        WHEN 1 THEN 'Санкт-Петербург'
        WHEN 2 THEN 'Казань'
        WHEN 3 THEN 'Сочи'
        WHEN 4 THEN 'Екатеринбург'
        WHEN 5 THEN 'Новосибирск'
        WHEN 6 THEN 'Нижний Новгород'
        WHEN 7 THEN 'Самара'
        WHEN 8 THEN 'Владивосток'
        ELSE 'Калининград'
    END AS location,
    ROUND((2500 + (gs % 140) * 120)::numeric, 2) AS price_per_night,
    DATE '2024-01-01' AS available_from,
    DATE '2028-12-31' AS available_to,
    TIMESTAMP '2023-12-01 08:00:00' + make_interval(mins => gs)
FROM generate_series(1, 50000) AS gs;

-- 1 200 000 бронирований. Каждому объекту достается 24 брони без пересечений.
WITH generated_bookings AS (
    SELECT
        gs AS booking_no,
        6 + ((gs - 1) % 50000) AS estate_id,
        ((gs - 1) / 50000) AS slot_no
    FROM generate_series(1, 1200000) AS gs
)
INSERT INTO bookings (
    estate_id,
    guest_id,
    start_date,
    end_date,
    total_price,
    created_at
)
SELECT
    g.estate_id,
    20009 + ((g.booking_no * 17) % 30000) AS guest_id,
    d.start_date,
    d.start_date + d.nights,
    ROUND(d.nights * e.price_per_night, 2) AS total_price,
    (
        (d.start_date - ((g.booking_no % 21) + 3))::timestamp
        + make_interval(hours => 8 + (g.booking_no % 11), mins => g.booking_no % 60)
    ) AS created_at
FROM generated_bookings g
JOIN estate e
  ON e.id = g.estate_id
CROSS JOIN LATERAL (
    SELECT
        (DATE '2024-01-10' + (g.slot_no * 11) + (g.estate_id % 5))::date AS start_date,
        (2 + (g.booking_no % 5))::int AS nights
) AS d;

-- Отзывы примерно на 10% броней.
INSERT INTO reviews (booking_id, rating, comment, created_at)
SELECT
    b.id,
    1 + (b.id % 5) AS rating,
    CASE b.id % 6
        WHEN 0 THEN 'Отличное размещение, все совпало с описанием.'
        WHEN 1 THEN 'Хороший вариант, особенно понравился район.'
        WHEN 2 THEN 'Нормально, но хотелось бы более ранний заезд.'
        WHEN 3 THEN 'Чисто, спокойно, удобное заселение.'
        WHEN 4 THEN 'Подходит для короткой деловой поездки.'
        ELSE 'Понравились локация и оснащение квартиры.'
    END,
    b.end_date::timestamp + INTERVAL '12 hours'
FROM bookings b
WHERE b.id > 6
  AND b.id % 10 = 0;
