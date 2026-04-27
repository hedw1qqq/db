# Отчет по лабораторной работе 6

## Тема

Разработка REST API для базы сервиса аренды жилья на `FastAPI` с использованием общей PostgreSQL-базы из ЛР4.

## Архитектура

- backend: `FastAPI`
- ORM: `SQLModel`
- драйвер PostgreSQL: `psycopg`
- база данных: общий контейнер [`lab4/docker-compose.yml`](C:/Users/ivglu/Desktop/education/лабы/databases/lab4/docker-compose.yml)


## Реализованные группы endpoint'ов

### CRUD для таблиц

- `GET/POST/PUT/DELETE /users`
- `GET/POST/PUT/DELETE /estates`
- `GET/POST/PUT/DELETE /bookings`

### Фильтрация, сортировка, пагинация

Поддержаны параметры вида:

- `page`
- `limit`
- `sort`
- `order`
- `filter`

### Представления из ЛР2

- `GET /views/booking-details`
- `GET /views/host-revenue-stats`
- `GET /views/guest-activity-month`

### Функции и процедуры из ЛР3

- `GET /functions/calc-booking-amount`
- `GET /functions/is-guest-active`
- `POST /procedures/create-booking`
- `POST /procedures/add-or-update-review`

### Отчеты

- `GET /reports/top-hosts`
- `GET /reports/revenue-by-location`
- `GET /reports/guest-spending`

### Документация

- Swagger UI: `/docs`
- OpenAPI JSON: `/openapi.json`

## Проверка

Проверочный прогон сохранен в [api_results.json](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/api_results.json) и формируется скриптом [smoke_test.py](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/smoke_test.py).

По фактическому прогону были подтверждены:

- `GET /health` вернул `{"status":"ok"}`.
- `POST/PUT/DELETE /users` отработали на тестовом пользователе `lab6_api_user@example.com`.
- `POST/PUT/DELETE /estates` отработали на тестовом объекте `Lab6 API Estate`.
- `POST/PUT/DELETE /bookings` отработали на отдельной тестовой броне, созданной через обычный CRUD-маршрут.
- `GET /views/booking-details` и `GET /views/host-revenue-stats` вернули корректные данные по фикстурам `Lab6`.
- `GET /functions/calc-booking-amount` вернул `20400.0` для объекта `701` и периода `2026-07-20 .. 2026-07-23`.
- `GET /functions/is-guest-active` вернул `true` для гостя `602`.
- `POST /procedures/create-booking` успешно создал отдельное бронирование через SQL-обертку над процедурой ЛР3.
- `POST /procedures/add-or-update-review` успешно создал отзыв к бронированию, созданному процедурой.
- `/docs` доступен с HTTP-статусом `200`.
- `/openapi.json` содержит заголовок `Lab 6 Rental API`.

## Вывод

1. API покрывает все обязательные части задания ЛР6.
2. База ЛР6 не дублируется и не поднимается отдельно: используется единый Docker-стенд из ЛР4.

