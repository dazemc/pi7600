from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from Config import get_settings
from Models import Base

_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        _engine = create_async_engine(get_settings().database_url, echo=False)
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(get_engine(), expire_on_commit=False)
    return _session_factory


async def get_db() -> AsyncIterator[AsyncSession]:
    async with get_session_factory()() as session:
        yield session


async def init_db() -> None:
    """Create tables directly, for tests and throwaway databases.

    Application startup runs Alembic migrations instead so existing databases
    are upgraded in place.
    """
    async with get_engine().begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


def run_migrations() -> None:
    """Apply Alembic migrations using the configured database URL.

    Alembic's async environment runs its own event loop, so callers inside an
    async context must invoke this through a thread.
    """
    from alembic.config import Config as AlembicConfig

    from alembic import command

    config = AlembicConfig("alembic.ini")
    config.set_main_option("sqlalchemy.url", get_settings().database_url)
    command.upgrade(config, "head")


async def close_db() -> None:
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _session_factory = None
