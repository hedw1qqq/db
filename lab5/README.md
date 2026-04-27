# Лабораторная работа 5

ЛР5 больше не поднимает отдельную БД. Она использует общий PostgreSQL-стенд из [`lab4/docker-compose.yml`](C:/Users/ivglu/Desktop/education/лабы/databases/lab4/docker-compose.yml), где уже собраны:

- схема и сиды из ЛР1-ЛР3;
- представления из ЛР2;
- функции, процедуры и триггеры из ЛР3;
- большой датасет из ЛР4;
- фикстуры для сценариев ЛР5;
- helper-функции для API ЛР6.

## Запуск общего стенда

Из корня проекта:

```powershell
docker compose -f .\lab4\docker-compose.yml up -d
```

## Установка зависимостей

```powershell
python -m pip install -r .\lab5\requirements.txt
```

## Прогон сценариев ЛР5

```powershell
docker compose -f .\lab4\docker-compose.yml up -d
docker exec -i lab4-postgres psql -U admin -d lab4 -f /workspace/lab5/20_transaction_scenarios.sql > .\lab5\results.txt
python .\lab5\run_concurrency.py
```

Если нужен полностью чистый стенд, пересоздай общий volume:

```powershell
docker compose -f .\lab4\docker-compose.yml down -v
docker compose -f .\lab4\docker-compose.yml up -d
```

Артефакты:

- [15_reset_helpers.sql](C:/Users/ivglu/Desktop/education/лабы/databases/lab5/15_reset_helpers.sql)
- [20_transaction_scenarios.sql](C:/Users/ivglu/Desktop/education/лабы/databases/lab5/20_transaction_scenarios.sql)
- [results.txt](C:/Users/ivglu/Desktop/education/лабы/databases/lab5/results.txt)
- [run_concurrency.py](C:/Users/ivglu/Desktop/education/лабы/databases/lab5/run_concurrency.py)
- [concurrency_results.txt](C:/Users/ivglu/Desktop/education/лабы/databases/lab5/concurrency_results.txt)
