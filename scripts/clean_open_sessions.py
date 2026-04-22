#!/usr/bin/env python3
import argparse
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path


def count_open(conn, table, id_col):
    cur = conn.execute(f"SELECT COUNT(*) FROM {table} WHERE stopped_at IS NULL")
    return cur.fetchone()[0]


def preview_open(conn, table, id_col):
    cur = conn.execute(
        f"SELECT id, {id_col}, started_at FROM {table} WHERE stopped_at IS NULL"
    )
    return cur.fetchall()


def fmt_ts(ts):
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def main():
    parser = argparse.ArgumentParser(
        description="Remove sessions with no end date from TimeControl.db"
    )
    parser.add_argument("db_path", help="Path to TimeControl.db")
    parser.add_argument(
        "--yes", "-y", action="store_true", help="Skip confirmation prompt"
    )
    args = parser.parse_args()

    db_path = Path(args.db_path).expanduser().resolve()
    if not db_path.exists():
        print(f"Error: file not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    tables = [
        ("task_sessions", "task_id"),
        ("subtask_sessions", "subtask_id"),
    ]

    total = 0
    for table, id_col in tables:
        rows = preview_open(conn, table, id_col)
        if rows:
            print(f"\n{table} — {len(rows)} open session(s):")
            for row in rows:
                print(f"  id={row[0]}  {id_col}={row[1]}  started_at={fmt_ts(row[2])}")
        else:
            print(f"\n{table} — no open sessions")
        total += len(rows)

    if total == 0:
        print("\nNothing to clean up.")
        conn.close()
        return

    print(f"\nTotal to delete: {total} session(s)")

    if not args.yes:
        answer = input("Delete these sessions? [y/N] ").strip().lower()
        if answer != "y":
            print("Aborted.")
            conn.close()
            return

    for table, _ in tables:
        cur = conn.execute(f"DELETE FROM {table} WHERE stopped_at IS NULL")
        print(f"Deleted {cur.rowcount} row(s) from {table}")

    conn.commit()
    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
