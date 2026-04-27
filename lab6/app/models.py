from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, field_validator
from sqlalchemy import Column, Date, DateTime, Enum as SAEnum, Numeric, String, Text
from sqlmodel import Field, SQLModel


class UserRole(str, Enum):
    guest = "guest"
    host = "host"
    both = "both"


# SQLModel-часть ниже описывает реальные таблицы PostgreSQL.
class User(SQLModel, table=True):
    __tablename__ = "users"

    id: int | None = Field(default=None, primary_key=True)
    name: str = Field(sa_column=Column(String(255), nullable=False))
    email: str = Field(sa_column=Column(String(255), nullable=False, unique=True))
    password_hash: str = Field(sa_column=Column(String(255), nullable=False))
    phone: str | None = Field(default=None, sa_column=Column(String(20), unique=True))
    role: UserRole = Field(
        sa_column=Column(SAEnum(UserRole, name="user_role", create_type=False), nullable=False)
    )


class Estate(SQLModel, table=True):
    __tablename__ = "estate"

    id: int | None = Field(default=None, primary_key=True)
    host_id: int = Field(foreign_key="users.id")
    name: str = Field(sa_column=Column(String(255), nullable=False))
    description: str | None = Field(default=None, sa_column=Column(Text))
    location: str = Field(sa_column=Column(String(255), nullable=False))
    price_per_night: float = Field(sa_column=Column(Numeric(10, 2), nullable=False))
    available_from: date = Field(sa_column=Column(Date, nullable=False))
    available_to: date = Field(sa_column=Column(Date, nullable=False))
    created_at: datetime = Field(sa_column=Column(DateTime, nullable=False))


class Booking(SQLModel, table=True):
    __tablename__ = "bookings"

    id: int | None = Field(default=None, primary_key=True)
    estate_id: int = Field(foreign_key="estate.id")
    guest_id: int = Field(foreign_key="users.id")
    start_date: date = Field(sa_column=Column(Date, nullable=False))
    end_date: date = Field(sa_column=Column(Date, nullable=False))
    total_price: float = Field(sa_column=Column(Numeric(10, 2), nullable=False))
    created_at: datetime | None = Field(default=None, sa_column=Column(DateTime, nullable=False))


class Review(SQLModel, table=True):
    __tablename__ = "reviews"

    id: int | None = Field(default=None, primary_key=True)
    booking_id: int = Field(foreign_key="bookings.id")
    rating: int
    comment: str | None = None
    created_at: datetime | None = Field(default=None, sa_column=Column(DateTime, nullable=False))


class Message(BaseModel):
    detail: str


# Базовая схема для ответов, которые читаются прямо из ORM-объектов.
class OrmReadModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserCreate(BaseModel):
    name: str
    email: str
    password_hash: str
    phone: str | None = None
    role: UserRole


class UserUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    password_hash: str | None = None
    phone: str | None = None
    role: UserRole | None = None


class UserRead(OrmReadModel):
    id: int
    name: str
    email: str
    phone: str | None = None
    role: UserRole


class EstateCreate(BaseModel):
    host_id: int
    name: str
    description: str | None = None
    location: str
    price_per_night: float
    available_from: date
    available_to: date


class EstateUpdate(BaseModel):
    host_id: int | None = None
    name: str | None = None
    description: str | None = None
    location: str | None = None
    price_per_night: float | None = None
    available_from: date | None = None
    available_to: date | None = None


class EstateRead(OrmReadModel):
    id: int
    host_id: int
    name: str
    description: str | None = None
    location: str
    price_per_night: float
    available_from: date
    available_to: date
    created_at: datetime

    @field_validator("price_per_night", mode="before")
    @classmethod
    def _coerce_price_per_night(cls, value: object) -> object:
        # В БД деньги приходят как Decimal, а наружу отдаем обычное число.
        return float(value) if isinstance(value, Decimal) else value


class BookingCreate(BaseModel):
    estate_id: int
    guest_id: int
    start_date: date
    end_date: date


class BookingUpdate(BaseModel):
    estate_id: int | None = None
    guest_id: int | None = None
    start_date: date | None = None
    end_date: date | None = None


class BookingRead(OrmReadModel):
    id: int
    estate_id: int
    guest_id: int
    start_date: date
    end_date: date
    total_price: float
    created_at: datetime

    @field_validator("total_price", mode="before")
    @classmethod
    def _coerce_total_price(cls, value: object) -> object:
        return float(value) if isinstance(value, Decimal) else value


class ReviewProcedureIn(BaseModel):
    booking_id: int
    rating: int
    comment: str | None = None


class ReviewRead(OrmReadModel):
    id: int
    booking_id: int
    rating: int
    comment: str | None = None
    created_at: datetime


class PageMeta(BaseModel):
    page: int
    limit: int
    total: int


class UserPage(PageMeta):
    items: list[UserRead]


class EstatePage(PageMeta):
    items: list[EstateRead]


class BookingPage(PageMeta):
    items: list[BookingRead]


class GenericPage(PageMeta):
    items: list[dict[str, Any]]


Order = Literal["asc", "desc"]
