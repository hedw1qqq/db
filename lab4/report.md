# Отчет по лабораторной работе 4

## Тема

Исследование индексирования и оптимизации запросов в PostgreSQL 16 на базе схемы сервиса аренды жилья из ЛР1-ЛР3.

## Основа работы

Использована та же модель данных:

- `users`
- `estate`
- `bookings`
- `reviews`

Дополнительно для ЛР4 был подготовлен большой датасет:

- `users`: 60 008 строк
- `estate`: 50 005 строк
- `bookings`: 1 200 006 строк
- `reviews`: 120 004 строки

Ключевая таблица для исследования индексирования: `bookings` с объемом более 1 млн строк.

## Методика

Для каждого сценария выполнялся один и тот же цикл:

1. запрос без дополнительного индекса;
2. `EXPLAIN (ANALYZE, BUFFERS)`;
3. формулировка гипотезы;
4. создание индекса;
5. повторный запуск;
6. сравнение времени и плана.

## Сценарий 1. Сложный фильтр

SQL-запрос:

```sql
SELECT b.id, b.guest_id, b.total_price, b.created_at
FROM bookings b
WHERE b.estate_id = 12020
  AND b.created_at >= TIMESTAMP '2024-04-01'
  AND b.created_at < TIMESTAMP '2024-08-01'
  AND b.total_price BETWEEN 30000 AND 35000;
```

Гипотеза:
составной индекс по `(estate_id, created_at)` должен резко сократить объем читаемых данных, потому что запрос использует точное равенство по `estate_id` и диапазон по `created_at`.

Индекс:

```sql
CREATE INDEX idx_lab4_bookings_estate_created
    ON bookings (estate_id, created_at);
```

Результат:

- До индекса: `Parallel Seq Scan`, `Execution Time: 42.783 ms`
- После индекса: `Bitmap Heap Scan` + `Bitmap Index Scan`, `Execution Time: 0.121 ms`
- Размер индекса: `36 MB`

Вывод:
гипотеза подтвердилась. Индекс сократил время примерно в 350 раз и убрал полное сканирование таблицы.

## Сценарий 2. Сортировка с ограничением

SQL-запрос:

```sql
SELECT b.id, b.estate_id, b.guest_id, b.created_at
FROM bookings b
WHERE b.created_at >= TIMESTAMP '2024-07-01'
ORDER BY b.created_at DESC
LIMIT 50;
```

Гипотеза:
B-tree индекс по `created_at DESC` позволит получить первые строки сразу из индекса без полного сканирования и сортировки.

Индекс:

```sql
CREATE INDEX idx_lab4_bookings_created_desc
    ON bookings (created_at DESC);
```

Результат:

- До индекса: `Parallel Seq Scan` + `Sort` + `Gather Merge`, `Execution Time: 43.595 ms`
- После индекса: `Index Scan using idx_lab4_bookings_created_desc`, `Execution Time: 0.098 ms`
- Размер индекса: `11 MB`

Вывод:
гипотеза подтвердилась. Это самый показательный случай для `ORDER BY ... LIMIT`: сортировка исчезла, а время уменьшилось более чем в 400 раз.

## Сценарий 3. Альтернативные варианты индексирования

SQL-запрос:

```sql
SELECT b.id, b.estate_id, b.created_at, b.total_price
FROM bookings b
WHERE b.guest_id = 24567
  AND b.created_at >= TIMESTAMP '2024-03-01'
  AND b.created_at < TIMESTAMP '2024-10-01';
```

Гипотеза:
порядок столбцов в составном индексе критичен. Для запроса с точным условием по `guest_id` и диапазоном по `created_at` индекс `(guest_id, created_at)` должен быть лучше, чем `(created_at, guest_id)`.

Вариант 1:

```sql
CREATE INDEX idx_lab4_bookings_created_guest
    ON bookings (created_at, guest_id);
```

Вариант 2:

```sql
CREATE INDEX idx_lab4_bookings_guest_created
    ON bookings (guest_id, created_at);
```

Результат:

- Без индекса: `Parallel Seq Scan`, `Execution Time: 36.154 ms`
- Индекс `(created_at, guest_id)`: план почти не изменился, `Execution Time: 38.298 ms`
- Индекс `(guest_id, created_at)`: `Bitmap Heap Scan` + `Bitmap Index Scan`, `Execution Time: 0.100 ms`
- Размер обоих индексов: `36 MB`

Вывод:
гипотеза полностью подтвердилась. Неправильный порядок полей почти бесполезен, правильный уменьшает время примерно в 360 раз.

## Сценарий 4. Текстовый поиск

SQL-запрос:

```sql
SELECT e.id, e.name, e.location
FROM estate e
WHERE e.description ILIKE '%панорамный вид на море%';
```

Гипотеза:
обычный B-tree здесь не подходит, а `GIN` с `pg_trgm` должен ускорить поиск по подстроке.

Индекс:

```sql
CREATE INDEX idx_lab4_estate_description_trgm
    ON estate
    USING GIN (description gin_trgm_ops);
```

Результат:

- До индекса: `Seq Scan on estate`, `Execution Time: 110.811 ms`
- После индекса: `Bitmap Heap Scan` + `Bitmap Index Scan`, `Execution Time: 13.710 ms`
- Размер индекса: `11 MB`

Вывод:
гипотеза подтвердилась. Для подстрочного поиска по тексту триграммный индекс оказался существенно эффективнее полного сканирования.

## Сценарий 5. JOIN нескольких таблиц

SQL-запрос:

```sql
SELECT b.id, e.name AS estate_name, e.location, u.name AS guest_name, b.total_price, b.created_at
FROM estate e
JOIN bookings b ON b.estate_id = e.id
JOIN users u ON u.id = b.guest_id
WHERE e.location = 'Казань'
  AND e.id BETWEEN 12000 AND 12100
  AND b.created_at >= TIMESTAMP '2024-05-01'
  AND b.created_at < TIMESTAMP '2024-09-01'
  AND b.total_price >= 18000;
```

Гипотеза:
если сначала сузить множество объектов, то индекс по `(estate_id, created_at)` позволит соединять `bookings` точечно, а не сканировать всю миллионную таблицу.

Индекс:

```sql
CREATE INDEX idx_lab4_bookings_estate_created_join
    ON bookings (estate_id, created_at);
```

Результат:

- До индекса: `Parallel Seq Scan on bookings` внутри `Hash Join`, `Execution Time: 47.739 ms`
- После индекса: `Nested Loop` + `Bitmap Heap Scan` + `Bitmap Index Scan`, `Execution Time: 0.400 ms`
- Размер индекса: `36 MB`

Вывод:
гипотеза подтвердилась. При селективном соединении индекс на внешнем ключе и диапазонной дате дал выигрыш более чем в 100 раз.

## Сценарий 6. Негативный сценарий

SQL-запрос:

```sql
SELECT AVG(b.total_price)
FROM bookings b
WHERE b.created_at >= TIMESTAMP '2024-01-01';
```

Гипотеза:
если условие выбирает почти всю таблицу, индекс по `created_at` не даст заметной пользы, и планировщик сохранит последовательное чтение.

Индекс:

```sql
CREATE INDEX idx_lab4_bookings_created_wide
    ON bookings (created_at);
```

Результат:

- До индекса: `Parallel Seq Scan`, `Execution Time: 60.233 ms`
- После индекса: снова `Parallel Seq Scan`, `Execution Time: 60.463 ms`
- Размер индекса: `11 MB`

Вывод:
гипотеза подтвердилась. Для низкоселективного условия индекс не используется и не улучшает запрос.

## Влияние индексов на INSERT и UPDATE

Для отдельного сравнения использовалась таблица `estate`, чтобы не смешивать эффект индексов с триггерами аудита из ЛР3.

Дополнительные индексы:

```sql
CREATE INDEX idx_lab4_estate_location ON estate (location);
CREATE INDEX idx_lab4_estate_description_trgm
    ON estate USING GIN (description gin_trgm_ops);
```

### INSERT

- Без дополнительных индексов: `Execution Time: 19.935 ms`
- С индексами: `Execution Time: 72.557 ms`

Вывод:
вставка замедлилась примерно в 3.6 раза, так как PostgreSQL должен поддерживать дополнительные структуры индексов.

### UPDATE

- Без дополнительных индексов: `Execution Time: 10.034 ms`
- С индексами: `Execution Time: 205.625 ms`

Вывод:
обновление текстового поля, участвующего в `GIN`-индексе, замедлилось особенно сильно, более чем в 20 раз.

## Общий вывод

1. B-tree эффективно работает для точных условий, диапазонов и `ORDER BY ... LIMIT`.
2. В составных индексах критичен порядок полей.
3. Для поиска по подстроке по тексту нужен специализированный индекс `GIN` + `pg_trgm`.
4. Для JOIN индекс особенно полезен, когда запрос сначала резко сокращает множество строк.
5. При низкой селективности индекс не помогает и может не использоваться вообще.
6. Любой дополнительный индекс ускоряет чтение, но ухудшает `INSERT/UPDATE`, особенно если индексируется изменяемое текстовое поле.

## Артефакты

- Сырые планы выполнения: [results.txt](C:/Users/ivglu/Desktop/education/лабы/databases/lab4/results.txt)
- Инструкция запуска: [README.md](C:/Users/ivglu/Desktop/education/лабы/databases/lab4/README.md)
- Скрипт экспериментов: [03_experiments.sql](C:/Users/ivglu/Desktop/education/лабы/databases/lab4/03_experiments.sql)
