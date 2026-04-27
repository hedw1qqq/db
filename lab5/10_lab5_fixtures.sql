-- Фикстуры ЛР5: минимальный стабильный набор записей для транзакционных сценариев.
INSERT INTO users (id, name, email, password_hash, phone, role) VALUES
    (101, 'Lab5 Host One', 'lab5_host_one@example.com', 'hash_lab5_host_one', '+79010000001', 'host'),
    (102, 'Lab5 Guest One', 'lab5_guest_one@example.com', 'hash_lab5_guest_one', '+79010000002', 'guest'),
    (103, 'Lab5 Guest Two', 'lab5_guest_two@example.com', 'hash_lab5_guest_two', '+79010000003', 'guest'),
    (104, 'Lab5 Host Two', 'lab5_host_two@example.com', 'hash_lab5_host_two', '+79010000004', 'host')
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
        201,
        101,
        'Lab5 Sea Studio',
        'Dedicated estate for booking and concurrency scenarios',
        'Kaliningrad',
        4500.00,
        DATE '2026-07-01',
        DATE '2026-12-31',
        TIMESTAMP '2026-06-01 09:00:00'
    ),
    (
        202,
        104,
        'Lab5 City Loft',
        'Dedicated estate for reschedule scenarios',
        'Nizhny Novgorod',
        6000.00,
        DATE '2026-07-01',
        DATE '2026-12-31',
        TIMESTAMP '2026-06-02 10:00:00'
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
        301,
        202,
        102,
        DATE '2026-07-10',
        DATE '2026-07-12',
        12000.00,
        TIMESTAMP '2026-06-05 11:00:00'
    ),
    (
        302,
        202,
        103,
        DATE '2026-07-18',
        DATE '2026-07-20',
        12000.00,
        TIMESTAMP '2026-06-05 12:00:00'
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
        401,
        301,
        4,
        'Base review for the reschedule scenario',
        TIMESTAMP '2026-07-13 15:00:00'
    )
ON CONFLICT (id) DO UPDATE
SET booking_id = EXCLUDED.booking_id,
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment,
    created_at = EXCLUDED.created_at;

-- Выравниваем sequence, чтобы следующие INSERT не упирались в фиксированные id.
SELECT setval(pg_get_serial_sequence('users', 'id'), (SELECT MAX(id) FROM users), true);
SELECT setval(pg_get_serial_sequence('estate', 'id'), (SELECT MAX(id) FROM estate), true);
SELECT setval(pg_get_serial_sequence('bookings', 'id'), (SELECT MAX(id) FROM bookings), true);
SELECT setval(pg_get_serial_sequence('reviews', 'id'), (SELECT MAX(id) FROM reviews), true);
