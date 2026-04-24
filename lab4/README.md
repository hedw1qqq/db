# Лабораторная работа 4



## Что внутри

- `docker-compose.yml` — отдельный PostgreSQL 16 для ЛР4 на порту `5434`.
- `00_extensions.sql` — подключение `pg_trgm`.
- `01_bulk_seed.sql` — генерация большого датасета:
  - `users` — 60 008 строк;
  - `estate` — 50 005 строк;
  - `bookings` — 1 200 006 строк;
  - `reviews` — около 120 004 строк.
- `02_postload.sql` — `ANALYZE` после загрузки.
- `03_experiments.sql` — все 6 обязательных сценариев и отдельный блок по `INSERT/UPDATE`.
- `Лабораторная работа №4.pdf` — исходное задание.

## Сценарии экспериментов

1. Сложный фильтр: `bookings` по `estate_id + created_at + total_price`.
2. Сортировка с ограничением: `ORDER BY created_at DESC LIMIT`.
3. Альтернативные индексы: сравнение `(created_at, guest_id)` и `(guest_id, created_at)`.
4. Текстовый поиск: `ILIKE '%панорамный вид на море%'` с `GIN + pg_trgm`.
5. JOIN: `estate + bookings + users` с фильтрацией по `location`, диапазону `estate.id` и `created_at`.
6. Негативный сценарий: широкий диапазон по `created_at`, где индекс не должен дать заметной пользы.

Дополнительно:

- сравнение `INSERT` и `UPDATE` для `estate` без дополнительных индексов и с ними.

## Как запустить

Из каталога [`lab4`](C:/Users/ivglu/Desktop/education/лабы/databases/lab4):

```powershell
docker compose up -d
docker exec -i lab4-postgres psql -U admin -d lab4 -f /workspace/lab4/03_experiments.sql > .\results.txt
```

Остановить и удалить контейнер с данными:

```powershell
docker compose down -v
```

## Что смотреть в `results.txt`

Для каждого сценария в отчёт нужно взять:

- текст SQL-запроса;
- гипотезу;
- план `EXPLAIN (ANALYZE, BUFFERS)` до индекса;
- план после индекса;
- время выполнения и изменения в плане;
- итоговый вывод.

