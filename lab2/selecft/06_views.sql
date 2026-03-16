CREATE OR REPLACE VIEW v_booking_details AS
SELECT
    b.id AS booking_id,
    b.start_date,
    b.end_date,
    b.total_price,
    g.id AS guest_id,
    g.name AS guest_name,
    h.id AS host_id,
    h.name AS host_name,
    e.id AS estate_id,
    e.name AS estate_name,
    e.location,
    r.rating,
    r.comment,
    r.created_at AS review_created_at
FROM bookings b
JOIN users g ON g.id = b.guest_id
JOIN estate e ON e.id = b.estate_id
JOIN users h ON h.id = e.host_id
LEFT JOIN reviews r ON r.booking_id = b.id;

CREATE OR REPLACE VIEW v_host_revenue_stats AS
SELECT
    h.id AS host_id,
    h.name AS host_name,
    COUNT(DISTINCT e.id) AS estates_total,
    COUNT(b.id) AS bookings_total,
    COALESCE(SUM(b.total_price), 0) AS revenue_total,
    COALESCE(AVG(b.total_price), 0) AS avg_booking_amount,
    MAX(b.end_date) AS last_booking_end_date
FROM users h
LEFT JOIN estate e ON e.host_id = h.id
LEFT JOIN bookings b ON b.estate_id = e.id
WHERE h.role IN ('host', 'both')
GROUP BY h.id, h.name;

CREATE OR REPLACE VIEW v_guest_activity_month AS
SELECT
    g.id AS guest_id,
    g.name AS guest_name,
    DATE_TRUNC('month', b.start_date)::date AS month_start,
    COUNT(b.id) AS bookings_total,
    COALESCE(SUM(b.total_price), 0) AS spent_total,
    COALESCE(AVG(r.rating), 0) AS avg_given_rating,
    MAX(b.created_at) AS last_booking_created_at
FROM users g
LEFT JOIN bookings b ON b.guest_id = g.id
LEFT JOIN reviews r ON r.booking_id = b.id
WHERE g.role IN ('guest', 'both')
GROUP BY g.id, g.name, DATE_TRUNC('month', b.start_date)
ORDER BY g.id, month_start;