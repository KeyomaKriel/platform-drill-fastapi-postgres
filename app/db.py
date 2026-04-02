import os

import psycopg
from psycopg.rows import dict_row


POSTGRES_HOST = os.getenv("POSTGRES_HOST", "127.0.0.1")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "55432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "platformdrill")
POSTGRES_USER = os.getenv("POSTGRES_USER", "platformuser")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "platformpass")


def get_connection():
    return psycopg.connect(
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        dbname=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        row_factory=dict_row,
    )


def init_db():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL
                )
                """
            )

            cur.execute("SELECT COUNT(*) AS count FROM items")
            row = cur.fetchone()

            if row["count"] == 0:
                cur.executemany(
                    "INSERT INTO items (id, name) VALUES (%s, %s)",
                    [
                        (1, "keyboard"),
                        (2, "monitor"),
                    ],
                )

        conn.commit()


def fetch_items():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name FROM items ORDER BY id")
            rows = cur.fetchall()
            return [{"id": row["id"], "name": row["name"]} for row in rows]


def db_is_ok():
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True
    except Exception:
        return False