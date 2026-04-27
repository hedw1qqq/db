from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from ..db import SessionDep


router = APIRouter(tags=["system"])


@router.get("/")
def root():
    return {
        "name": "Lab 6 Rental API",
        "docs": "/docs",
        "openapi": "/openapi.json",
    }


@router.get("/health")
def health(session: SessionDep):
    # Простейшая проверка: API видит БД и может выполнить запрос.
    session.execute(text("SELECT 1"))
    return {"status": "ok"}
