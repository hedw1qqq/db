-- ЛР3: функции, процедуры и триггеры для базы аренды.
-- Скрипт можно запускать повторно.

-- Чистим объекты, чтобы повторный запуск не падал.
DROP TRIGGER IF EXISTS trg_bookings_validate ON bookings;
DROP TRIGGER IF EXISTS trg_bookings_audit ON bookings;

DROP FUNCTION IF EXISTS trg_bookings_validate();
DROP FUNCTION IF EXISTS trg_bookings_audit();

DROP PROCEDURE IF EXISTS pr_create_booking(INT, INT, DATE, DATE, INT);
DROP PROCEDURE IF EXISTS pr_add_or_update_review(INT, INT, TEXT);

DROP FUNCTION IF EXISTS fn_calc_booking_amount(INT, DATE, DATE);
DROP FUNCTION IF EXISTS fn_is_guest_active(INT, INT);

-- Таблица для истории изменений в bookings.
CREATE TABLE IF NOT EXISTS booking_audit (
    id BIGSERIAL PRIMARY KEY,
    booking_id INT NOT NULL,
    action_type VARCHAR(10) NOT NULL CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_total_price NUMERIC(10, 2),
    new_total_price NUMERIC(10, 2),
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor TEXT NOT NULL DEFAULT CURRENT_USER
);

-- Считаем стоимость брони: количество ночей * цена за ночь.

CREATE OR REPLACE FUNCTION fn_calc_booking_amount(
    p_estate_id INT,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_price NUMERIC(10, 2);
    v_days INT;
BEGIN
    -- Проверяем, что даты заданы и период нормальный.
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date >= p_end_date THEN
        RAISE EXCEPTION 'Некорректный период бронирования: start_date=%, end_date=%', p_start_date, p_end_date;
    END IF;

    -- Берем цену за ночь у нужного объекта.
    SELECT e.price_per_night
    INTO v_price
    FROM estate e
    WHERE e.id = p_estate_id;

    -- Если объекта нет, считаем это ошибкой.
    IF v_price IS NULL THEN
        RAISE EXCEPTION 'Объект с id=% не найден', p_estate_id;
    END IF;

    -- Разница дат в PostgreSQL дает число ночей.
    v_days := (p_end_date - p_start_date);
    RETURN ROUND(v_days * v_price, 2);
EXCEPTION
    WHEN data_exception THEN
        RAISE EXCEPTION 'Ошибка расчета стоимости: некорректные входные данные';
END;
$$;

-- Проверяем, был ли гость активен за последние p_days дней.

CREATE OR REPLACE FUNCTION fn_is_guest_active(
    p_guest_id INT,
    p_days INT DEFAULT 90
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_bookings_cnt INT;
BEGIN
    -- Дней должно быть больше нуля.
    IF p_days <= 0 THEN
        RAISE EXCEPTION 'Параметр p_days должен быть положительным';
    END IF;

    -- Убеждаемся, что это реальный пользователь с ролью гостя.
    IF NOT EXISTS (
        SELECT 1
        FROM users u
        WHERE u.id = p_guest_id
          AND u.role IN ('guest', 'both')
    ) THEN
        RAISE EXCEPTION 'Пользователь с id=% не является гостем или не существует', p_guest_id;
    END IF;

    -- Считаем, сколько броней создано за выбранный период.
    SELECT COUNT(*)
    INTO v_bookings_cnt
    FROM bookings b
    WHERE b.guest_id = p_guest_id
      AND b.created_at >= CURRENT_TIMESTAMP - make_interval(days => p_days);

    RETURN v_bookings_cnt > 0;
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE EXCEPTION 'Ошибка в параметрах функции fn_is_guest_active';
END;
$$;

-- Создаем бронирование с основными проверками.
-- Новый id возвращается через INOUT-параметр.
CREATE OR REPLACE PROCEDURE pr_create_booking(
    IN p_estate_id INT,
    IN p_guest_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    INOUT p_booking_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_host_id INT;
    v_available_from DATE;
    v_available_to DATE;
    v_total_price NUMERIC(10, 2);
BEGIN
    -- Проверка дат.
    IF p_start_date >= p_end_date THEN
        RAISE EXCEPTION 'Дата начала должна быть раньше даты окончания';
    END IF;

    -- Пользователь должен иметь роль guest или both.
    IF NOT EXISTS (
        SELECT 1
        FROM users u
        WHERE u.id = p_guest_id
          AND u.role IN ('guest', 'both')
    ) THEN
        RAISE EXCEPTION 'Нельзя создать бронирование: пользователь id=% не может быть гостем', p_guest_id;
    END IF;

    -- Загружаем параметры объекта: владелец и доступные даты.
    SELECT e.host_id, e.available_from, e.available_to
    INTO v_host_id, v_available_from, v_available_to
    FROM estate e
    WHERE e.id = p_estate_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Нельзя создать бронирование: объект id=% не найден', p_estate_id;
    END IF;

    -- Владелец не может бронировать свое жилье.
    IF v_host_id = p_guest_id THEN
        RAISE EXCEPTION 'Нельзя создать бронирование: хост не может бронировать свой объект';
    END IF;

    -- Даты брони должны попадать в период доступности.
    IF p_start_date < v_available_from OR p_end_date > v_available_to THEN
        RAISE EXCEPTION 'Нельзя создать бронирование: даты выходят за доступный период объекта';
    END IF;

    -- Проверяем, что нет пересечений с уже занятыми датами.
    IF EXISTS (
        SELECT 1
        FROM bookings b
        WHERE b.estate_id = p_estate_id
          AND daterange(b.start_date, b.end_date, '[)') && daterange(p_start_date, p_end_date, '[)')
    ) THEN
        RAISE EXCEPTION 'Нельзя создать бронирование: выбранный период уже занят';
    END IF;

    -- Считаем итоговую сумму.
    v_total_price := fn_calc_booking_amount(p_estate_id, p_start_date, p_end_date);

    -- Вставляем запись и возвращаем id.
    INSERT INTO bookings (estate_id, guest_id, start_date, end_date, total_price)
    VALUES (p_estate_id, p_guest_id, p_start_date, p_end_date, v_total_price)
    RETURNING id INTO p_booking_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Ошибка бизнес-логики: конфликт уникальности при создании бронирования';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Ошибка бизнес-логики: ссылка на несуществующий объект или гостя';
    WHEN check_violation THEN
        RAISE EXCEPTION 'Ошибка бизнес-логики: нарушены ограничения таблицы bookings';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка создания бронирования: %', SQLERRM;
END;
$$;

-- Добавляем отзыв или обновляем, если он уже есть.
CREATE OR REPLACE PROCEDURE pr_add_or_update_review(
    IN p_booking_id INT,
    IN p_rating INT,
    IN p_comment TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Оценка только от 1 до 5.
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Оценка должна быть от 1 до 5';
    END IF;

    -- Пытаемся вставить новый отзыв.
    INSERT INTO reviews (booking_id, rating, comment)
    VALUES (p_booking_id, p_rating, p_comment);
EXCEPTION
    -- Если отзыв уже был, обновляем его.
    WHEN unique_violation THEN
        UPDATE reviews
        SET rating = p_rating,
            comment = p_comment,
            created_at = CURRENT_TIMESTAMP
        WHERE booking_id = p_booking_id;
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Нельзя добавить отзыв: бронирование id=% не найдено', p_booking_id;
    WHEN check_violation THEN
        RAISE EXCEPTION 'Нельзя добавить отзыв: некорректное значение rating';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка добавления/обновления отзыва: %', SQLERRM;
END;
$$;

-- Триггер проверяет даты перед вставкой/обновлением брони.

CREATE OR REPLACE FUNCTION trg_bookings_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Дата начала должна быть раньше даты окончания.
    IF NEW.start_date >= NEW.end_date THEN
        RAISE EXCEPTION 'Нарушение правила: start_date должна быть меньше end_date';
    END IF;

    -- Не даем пересекаться с другими бронями этого объекта.
    -- При UPDATE исключаем текущую запись по id.
    IF EXISTS (
        SELECT 1
        FROM bookings b
        WHERE b.estate_id = NEW.estate_id
          AND b.id <> COALESCE(NEW.id, -1)
          AND daterange(b.start_date, b.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)')
    ) THEN
        RAISE EXCEPTION 'Нарушение правила: период бронирования пересекается с существующим';
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Триггер валидации bookings: %', SQLERRM;
END;
$$;

-- Триггер пишет в аудит все изменения по bookings.

CREATE OR REPLACE FUNCTION trg_bookings_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Для каждого типа операции пишем нужные старые/новые значения.
    IF TG_OP = 'INSERT' THEN
        INSERT INTO booking_audit (booking_id, action_type, old_total_price, new_total_price)
        VALUES (NEW.id, 'INSERT', NULL, NEW.total_price);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO booking_audit (booking_id, action_type, old_total_price, new_total_price)
        VALUES (NEW.id, 'UPDATE', OLD.total_price, NEW.total_price);
        RETURN NEW;
    ELSE
        INSERT INTO booking_audit (booking_id, action_type, old_total_price, new_total_price)
        VALUES (OLD.id, 'DELETE', OLD.total_price, NULL);
        RETURN OLD;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Триггер аудита bookings: %', SQLERRM;
END;
$$;

-- Подключаем триггер валидации.
CREATE TRIGGER trg_bookings_validate
BEFORE INSERT OR UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION trg_bookings_validate();

-- Подключаем триггер аудита.
CREATE TRIGGER trg_bookings_audit
AFTER INSERT OR UPDATE OR DELETE ON bookings
FOR EACH ROW
EXECUTE FUNCTION trg_bookings_audit();
