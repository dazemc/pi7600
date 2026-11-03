#!/usr/bin/env python3
"""Create a Pi7600 API user."""

import argparse
import asyncio
import os
import sys
from getpass import getpass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

from sqlalchemy import select  # noqa: E402
from sqlalchemy.ext.asyncio import (  # noqa: E402
    async_sessionmaker,
    create_async_engine,
)

from Config import get_settings  # noqa: E402
from Models import Base, UserDB  # noqa: E402
from Utils import hash_password  # noqa: E402


async def create_user(username: str, password: str, is_admin: bool) -> None:
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)

        session_factory = async_sessionmaker(engine, expire_on_commit=False)
        async with session_factory() as session:
            existing = await session.scalar(
                select(UserDB).where(UserDB.user_name == username)
            )
            if existing is not None:
                raise SystemExit(f"User '{username}' already exists.")

            session.add(
                UserDB(
                    user_name=username,
                    user_password=hash_password(password),
                    is_admin=is_admin,
                )
            )
            await session.commit()
    finally:
        await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--admin", action="store_true", help="grant admin access")
    args = parser.parse_args()

    username = input("Username: ").strip()
    if not username:
        raise SystemExit("Username cannot be empty.")

    password = getpass("Password: ")
    confirmation = getpass("Confirm password: ")
    if not password:
        raise SystemExit("Password cannot be empty.")
    if password != confirmation:
        raise SystemExit("Passwords do not match.")

    asyncio.run(create_user(username, password, args.admin))
    print(f"User '{username}' created successfully.")


if __name__ == "__main__":
    main()
