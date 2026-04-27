from __future__ import annotations

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DBAPIError, DataError, IntegrityError, ProgrammingError

from .helpers import db_exception_to_http
from .routes import routers


# Собираем приложение из разнесенных по модулям роутов.
app = FastAPI(
    title="Lab 6 Rental API",
    version="1.0.0",
    description="FastAPI backend for the rental database from labs 1-5 running on the shared PostgreSQL stand from lab 4.",
)

for router in routers:
    app.include_router(router)


# Все низкоуровневые ошибки БД сводим к единообразному JSON-ответу.
def _db_error_response(exc: Exception) -> JSONResponse:
    http_exc = db_exception_to_http(exc)
    return JSONResponse(status_code=http_exc.status_code, content={"detail": http_exc.detail})


@app.exception_handler(IntegrityError)
async def integrity_error_handler(_request, exc: IntegrityError):
    return _db_error_response(exc)


@app.exception_handler(DataError)
async def data_error_handler(_request, exc: DataError):
    return _db_error_response(exc)


@app.exception_handler(ProgrammingError)
async def programming_error_handler(_request, exc: ProgrammingError):
    return _db_error_response(exc)


@app.exception_handler(DBAPIError)
async def dbapi_error_handler(_request, exc: DBAPIError):
    return _db_error_response(exc)
