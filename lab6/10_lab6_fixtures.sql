-- Фикстуры ЛР6 нужны для стабильных GET/PUT/DELETE проверок в smoke test и Swagger.
INSERT INTO users (id, name, email, password_hash, phone, role) VALUES
    (601, 'Lab6 Host', 'lab6_host@example.com', 'hash_lab6_host', '+79020000001', 'host'),
    (602, 'Lab6 Guest', 'lab6_guest@example.com', 'hash_lab6_guest', '+79020000002', 'guest'),
    (603, 'Lab6 Both', 'lab6_both@example.com', 'hash_lab6_both', '+79020000003', 'both')
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;

INSERT INTO estate (
    id,
    host_id,
    name,
    description,
    location,
    price_per_night,
    available_from,
    available_to,
    created_at
) VALUES
    (
        701,
        601,
        'Lab6 Demo Estate',
        'Dedicated estate for REST API checks',
        'Moscow',
        6800.00,
        DATE '2026-07-01',
        DATE '2026-12-31',
        TIMESTAMP '2026-06-01 12:00:00'
    ),
    (
        702,
        601,
        'Lab6 Country House',
        'Second estate to make list endpoints more useful',
        'Tver',
        9200.00,
        DATE '2026-07-01',
        DATE '2026-12-31',
        TIMESTAMP '2026-06-02 12:00:00'
    )
ON CONFLICT (id) DO UPDATE
SET host_id = EXCLUDED.host_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    location = EXCLUDED.location,
    price_per_night = EXCLUDED.price_per_night,
    available_from = EXCLUDED.available_from,
    available_to = EXCLUDED.available_to,
    created_at = EXCLUDED.created_at;

INSERT INTO bookings (
    id,
    estate_id,
    guest_id,
    start_date,
    end_date,
    total_price,
    created_at
) VALUES
    (
        801,
        701,
        602,
        DATE '2026-07-05',
        DATE '2026-07-07',
        13600.00,
        TIMESTAMP '2026-06-10 14:00:00'
    )
ON CONFLICT (id) DO UPDATE
SET estate_id = EXCLUDED.estate_id,
    guest_id = EXCLUDED.guest_id,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    total_price = EXCLUDED.total_price,
    created_at = EXCLUDED.created_at;

INSERT INTO reviews (id, booking_id, rating, comment, created_at) VALUES
    (
        901,
        801,
        5,
        'Seed review for API demo',
        TIMESTAMP '2026-07-08 09:30:00'
    )
ON CONFLICT (id) DO UPDATE
SET booking_id = EXCLUDED.booking_id,
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment,
    created_at = EXCLUDED.created_at;

-- Поднимаем sequence выше фиксированных id, чтобы CRUD работал без конфликтов.
SELECT setval(pg_get_serial_sequence('users', 'id'), (SELECT MAX(id) FROM users), true);
SELECT setval(pg_get_serial_sequence('estate', 'id'), (SELECT MAX(id) FROM estate), true);
SELECT setval(pg_get_serial_sequence('bookings', 'id'), (SELECT MAX(id) FROM bookings), true);
SELECT setval(pg_get_serial_sequence('reviews', 'id'), (SELECT MAX(id) FROM reviews), true);
