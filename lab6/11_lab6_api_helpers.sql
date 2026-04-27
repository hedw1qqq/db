-- SQL-обертки позволяют вызывать процедуры ЛР3 из HTTP как обычные функции.
CREATE OR REPLACE FUNCTION fn_api_create_booking(
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
    -- Возвращаем только id, а сам объект дочитываем уже на стороне FastAPI.
    CALL pr_create_booking(p_estate_id, p_guest_id, p_start_date, p_end_date, v_booking_id);
    RETURN v_booking_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_api_add_or_update_review(
    p_booking_id INT,
    p_rating INT,
    p_comment TEXT DEFAULT NULL
)
RETURNS TABLE (
    id INT,
    booking_id INT,
    rating INT,
    comment TEXT,
    created_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- После вызова процедуры сразу отдаём актуальный отзыв по booking_id.
    CALL pr_add_or_update_review(p_booking_id, p_rating, p_comment);

    RETURN QUERY
    SELECT r.id, r.booking_id, r.rating, r.comment, r.created_at
    FROM reviews r
    WHERE r.booking_id = p_booking_id;
END;
$$;
