# Лабораторная работа 6

ЛР6 использует тот же PostgreSQL-стенд, что и ЛР4 и ЛР5: [`lab4/docker-compose.yml`](C:/Users/ivglu/Desktop/education/лабы/databases/lab4/docker-compose.yml). Отдельного compose для ЛР6 нет.

## Что внутри

- [requirements.txt](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/requirements.txt) — зависимости `FastAPI`/`SQLModel`.
- [app/main.py](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/app/main.py) — сборка приложения и обработчики ошибок.
- [app/models.py](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/app/models.py) — SQLModel-модели и схемы API.
- [app/routes](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/app/routes) — маршруты API по разделам.
- [app/helpers.py](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/app/helpers.py) — общие хелперы для CRUD и сериализации SQL-view/report ответов.
- [10_lab6_fixtures.sql](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/10_lab6_fixtures.sql) — стабильные записи для проверки API.
- [11_lab6_api_helpers.sql](C:/Users/ivglu/Desktop/education/лабы/databases/lab6/11_lab6_api_helpers.sql) — SQL-обертки для вызова процедур ЛР3 из HTTP.

## Запуск

1. Поднять общий PostgreSQL-стенд:

```powershell
docker compose -f .\lab4\docker-compose.yml up -d
```

2. Установить зависимости:

```powershell
python -m pip install -r .\lab6\requirements.txt
```

3. Запустить API:

```powershell
uvicorn app.main:app --app-dir .\lab6 --host 127.0.0.1 --port 8006
```

4. Прогнать проверку endpoint'ов:

```powershell
python .\lab6\smoke_test.py
```

## Документация

- Swagger UI: `http://127.0.0.1:8006/docs`
- OpenAPI JSON: `http://127.0.0.1:8006/openapi.json`
