#!/usr/bin/env python3

from getpass import getpass

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from Models import Base, UserDB
from Utils import hash_password

DATABASE_URL = "sqlite:///./cmgl.db"

engine = create_engine(DATABASE_URL)
Base.metadata.create_all(engine)

username = input("Username: ").strip()
if not username:
    raise SystemExit("Username cannot be empty.")

password = getpass("Password: ")
confirmation = getpass("Confirm password: ")

if not password:
    raise SystemExit("Password cannot be empty.")

if password != confirmation:
    raise SystemExit("Passwords do not match.")

with Session(engine) as session:
    existing = session.query(UserDB).filter_by(user_name=username).first()

    if existing:
        raise SystemExit(f"User '{username}' already exists.")

    user = UserDB(
        user_name=username,
        user_password=hash_password(password),
    )
    session.add(user)
    session.commit()

print(f"User '{username}' created successfully.")
