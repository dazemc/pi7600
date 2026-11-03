"""Initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-11-02

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _table_names() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def upgrade() -> None:
    tables = _table_names()

    if "messages" not in tables:
        op.create_table(
            "messages",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("message_index", sa.String(), nullable=True),
            sa.Column("message_type", sa.String(), nullable=False),
            sa.Column("message_originating_address", sa.String(), nullable=True),
            sa.Column("message_destination_address", sa.String(), nullable=True),
            sa.Column("message_date", sa.String(), nullable=False),
            sa.Column("message_time", sa.String(), nullable=False),
            sa.Column("message_contents", sa.String(), nullable=False),
            sa.Column("partial_key", sa.String(), nullable=True),
            sa.Column("partial_count", sa.Integer(), nullable=True),
            sa.Column("partial_index", sa.Integer(), nullable=True),
            sa.Column("is_partial", sa.Boolean(), nullable=False),
            sa.Column("in_sim_memory", sa.Boolean(), nullable=True),
            sa.Column("is_sent", sa.Boolean(), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_messages_id", "messages", ["id"], unique=False)

    if "users" not in tables:
        op.create_table(
            "users",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("user_name", sa.String(), nullable=False),
            sa.Column("user_password", sa.LargeBinary(), nullable=False),
            sa.Column("user_full_name", sa.String(), nullable=True),
            sa.Column("user_email", sa.String(), nullable=True),
            sa.Column(
                "is_disabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
            sa.Column(
                "is_admin",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_users_id", "users", ["id"], unique=False)
        op.create_index("ix_users_user_name", "users", ["user_name"], unique=True)
        return

    inspector = sa.inspect(op.get_bind())
    columns = {column["name"] for column in inspector.get_columns("users")}
    if "is_admin" not in columns:
        with op.batch_alter_table("users") as batch:
            batch.add_column(
                sa.Column(
                    "is_admin",
                    sa.Boolean(),
                    nullable=False,
                    server_default=sa.false(),
                )
            )

    indexes = {index["name"] for index in inspector.get_indexes("users")}
    if "ix_users_user_name" not in indexes:
        op.create_index("ix_users_user_name", "users", ["user_name"], unique=True)


def downgrade() -> None:
    tables = _table_names()
    if "users" in tables:
        op.drop_table("users")
    if "messages" in tables:
        op.drop_table("messages")
