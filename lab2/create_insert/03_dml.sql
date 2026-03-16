INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Никита Громов', 'nikita.gromov@example.com', 'hash_nikita', '+79000000009', 'guest');

INSERT INTO bookings (estate_id, guest_id, start_date, end_date, total_price)
VALUES (2, 9, '2026-06-10', '2026-06-13', 16800.00);

UPDATE estate
SET price_per_night = price_per_night * 1.08
WHERE location = 'Сочи';

UPDATE users
SET role = 'both'
WHERE id = 9;

DELETE FROM reviews
WHERE rating = 3;