SELECT
    b.id AS booking_id,
    b.start_date,
    b.end_date,
    b.total_price,
    g.name AS guest_name,
    h.name AS host_name,
    e.name AS estate_name,
    e.location
FROM bookings b
INNER JOIN users g ON g.id = b.guest_id
INNER JOIN estate e ON e.id = b.estate_id
INNER JOIN users h ON h.id = e.host_id
ORDER BY b.start_date;

SELECT
    e.id AS estate_id,
    e.name AS estate_name,
    e.location,
    COUNT(b.id) AS bookings_count,
    COALESCE(SUM(b.total_price), 0) AS revenue
FROM estate e
LEFT JOIN bookings b ON b.estate_id = e.id
GROUP BY e.id, e.name, e.location
ORDER BY revenue DESC, e.id;

SELECT
    u.id AS guest_id,
    u.name AS guest_name,
    b.id AS booking_id,
    r.rating,
    r.comment
FROM users u
LEFT JOIN bookings b ON b.guest_id = u.id
LEFT JOIN reviews r ON r.booking_id = b.id
WHERE u.role IN ('guest', 'both')
ORDER BY u.id, b.id;