SELECT
    e.location,
    COUNT(b.id) AS bookings_count,
    SUM(b.total_price) AS total_revenue,
    AVG(b.total_price) AS avg_booking_amount,
    MIN(b.total_price) AS min_booking_amount,
    MAX(b.total_price) AS max_booking_amount
FROM bookings b
JOIN estate e ON e.id = b.estate_id
GROUP BY e.location
HAVING COUNT(b.id) >= 1
ORDER BY total_revenue DESC;

SELECT
    u.id AS host_id,
    u.name AS host_name,
    COUNT(e.id) AS estates_count,
    AVG(e.price_per_night) AS avg_price_per_night,
    MIN(e.price_per_night) AS min_price_per_night,
    MAX(e.price_per_night) AS max_price_per_night
FROM users u
JOIN estate e ON e.host_id = u.id
GROUP BY u.id, u.name
HAVING COUNT(e.id) >= 1
ORDER BY avg_price_per_night DESC;

SELECT
    EXTRACT(MONTH FROM b.start_date) AS month_num,
    COUNT(*) AS bookings_total,
    SUM(b.total_price) AS month_revenue,
    AVG(b.total_price) AS month_avg_check
FROM bookings b
GROUP BY EXTRACT(MONTH FROM b.start_date)
ORDER BY month_num;