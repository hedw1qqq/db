from __future__ import annotations

import os
from typing import Annotated

from fastapi import Depends
from sqlmodel import Session, create_engine


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://admin:admin@localhost:5434/lab4",
)

# Один engine на приложение, а сессия создается на каждый запрос отдельно.
engine = create_engine(DATABASE_URL, pool_pre_ping=True)


def get_session():
    with Session(engine) as session:
        try:
            yield session
        except Exception:
            # Если обработчик упал посреди транзакции, не оставляем "грязную" сессию.
            session.rollback()
            raise


SessionDep = Annotated[Session, Depends(get_session)]
