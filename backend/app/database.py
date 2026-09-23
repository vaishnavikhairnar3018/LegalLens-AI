import logging
from typing import Optional
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from app.config import get_settings

logger = logging.getLogger("lensescan.database")
settings = get_settings()


def _build_engine(db_url: str):
    """Build async engine with appropriate parameters based on dialect."""
    is_sqlite = "sqlite" in db_url
    engine_kwargs = {"echo": settings.DEBUG}
    if is_sqlite:
        engine_kwargs["connect_args"] = {"check_same_thread": False}
    else:
        engine_kwargs.update({
            "pool_size": 20,
            "max_overflow": 10,
            "pool_pre_ping": True,
        })
    return create_async_engine(db_url, **engine_kwargs)


engine = _build_engine(settings.DATABASE_URL)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""
    pass


def get_session_factory():
    """Return active session factory (supports dynamic engine switches)."""
    return async_session_factory


async def get_db() -> AsyncSession:
    """
    FastAPI dependency that yields an async database session.
    Ensures proper cleanup on request completion.
    """
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """
    Create all tables. Called on application startup.
    If configured PostgreSQL is unreachable, seamlessly falls back to local SQLite.
    """
    global engine, async_session_factory
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as exc:
        if "sqlite" not in settings.DATABASE_URL:
            logger.warning(
                f"PostgreSQL server unreachable ({exc}). "
                "Switching seamlessly to local SQLite (sqlite+aiosqlite:///./lensescan.db)."
            )
            fallback_url = "sqlite+aiosqlite:///./lensescan.db"
            engine = _build_engine(fallback_url)
            async_session_factory = async_sessionmaker(
                engine,
                class_=AsyncSession,
                expire_on_commit=False,
            )
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            logger.info("Local SQLite database initialized at lensescan.db.")
        else:
            raise
