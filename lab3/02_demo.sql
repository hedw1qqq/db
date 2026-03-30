

-- 1) Успешное создание бронирования через процедуру
-- Создаем бронь и выводим ее id.
DO $$
DECLARE
    v_booking_id INT;
BEGIN
    CALL pr_create_booking(2, 3, DATE '2026-06-01', DATE '2026-06-04', v_booking_id);
    RAISE NOTICE 'Создано бронирование с id=%', v_booking_id;
END;
$$;

-- 2) Проверяем ошибку на некорректном периоде (один и тот же день).
DO $$
DECLARE
    v_booking_id INT;
BEGIN
    CALL pr_create_booking(2, 6, DATE '2026-03-21', DATE '2026-03-21', v_booking_id);
EXCEPTION
    WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка создания бронирования: %', SQLERRM;
END;
$$;

-- 3) Примеры вызова функций
-- Расчет стоимости для конкретного периода.
SELECT fn_calc_booking_amount(1, DATE '2026-07-01', DATE '2026-07-05') AS expected_total_price;

-- Смотрим активность гостей за последние 120 дней.
SELECT
    u.id,
    u.name,
    fn_is_guest_active(u.id, 120) AS is_active_last_120_days
FROM users u
WHERE u.role IN ('guest', 'both')
ORDER BY u.id;

-- 4) Добавление/обновление отзыва через процедуру (обрабатывается конфликт уникальности)
-- Первый вызов добавит отзыв.
-- Второй вызов обновит его, так как booking_id тот же.
CALL pr_add_or_update_review(4, 5, 'Прекрасный дом, рекомендую.');
CALL pr_add_or_update_review(4, 4, 'Обновленный отзыв после повторного проживания.');

-- 5) Демонстрация триггера: блокировка некорректного обновления
-- Пытаемся сломать диапазон дат, триггер должен не пропустить.
DO $$
BEGIN
    UPDATE bookings
    SET start_date = DATE '2026-03-21',
        end_date = DATE '2026-03-21'
    WHERE id = 1;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Триггер заблокировал некорректное обновление: %', SQLERRM;
END;
$$;

-- 6) Демонстрация операции удаления и аудита через триггер
-- Удаляем бронь из шага 1, чтобы в аудите появилась операция DELETE.
DELETE FROM bookings
WHERE id = (
    SELECT b.id
    FROM bookings b
    WHERE b.estate_id = 2
      AND b.guest_id = 3
      AND b.start_date = DATE '2026-06-01'
    ORDER BY b.id DESC
    LIMIT 1
);

-- Смотрим последние записи в аудите.
SELECT
    ba.id,
    ba.booking_id,
    ba.action_type,
    ba.old_total_price,
    ba.new_total_price,
    ba.changed_at
FROM booking_audit ba
ORDER BY ba.id DESC
LIMIT 15;

-- 7) Проверяем ошибку внешнего ключа на несуществующем бронировании.
DO $$
BEGIN
    CALL pr_add_or_update_review(999999, 5, 'Тест несуществующего бронирования');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка добавления отзыва: %', SQLERRM;
END;
$$;