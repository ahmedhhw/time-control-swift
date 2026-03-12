#!/usr/bin/env python3
"""
Remove sessions shorter than 30 seconds from tasks and subtasks in a todos.json file.

Usage:
    python3 filter_sessions.py <input.json> [output.json]

If output.json is omitted, the input file is overwritten (after making a .bak backup).
"""

import json
import shutil
import sys
from pathlib import Path

MIN_DURATION = 30  # seconds


def filter_sessions(sessions: list[dict]) -> tuple[list[dict], int]:
    """Return (kept_sessions, removed_count)."""
    kept = []
    removed = 0
    for s in sessions:
        start = s.get("startedAt")
        stop = s.get("stoppedAt")
        if start is None or stop is None:
            # Keep open/malformed sessions as-is
            kept.append(s)
            continue
        if stop - start >= MIN_DURATION:
            kept.append(s)
        else:
            removed += 1
    return kept, removed


def process(data: dict) -> dict:
    tasks = data.get("tasks", {})
    task_removed = 0
    subtask_removed = 0

    for task in tasks.values():
        kept, n = filter_sessions(task.get("sessions", []))
        task["sessions"] = kept
        task_removed += n

        for subtask in task.get("subtasks", []):
            kept_sub, n_sub = filter_sessions(subtask.get("sessions", []))
            subtask["sessions"] = kept_sub
            subtask_removed += n_sub

    print(f"Removed {task_removed} task session(s) and {subtask_removed} subtask session(s).")
    return data


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) >= 3 else input_path

    if not input_path.exists():
        print(f"Error: {input_path} not found.")
        sys.exit(1)

    with input_path.open() as f:
        data = json.load(f)

    if output_path == input_path:
        backup = input_path.with_suffix(".json.bak")
        shutil.copy2(input_path, backup)
        print(f"Backup saved to {backup}")

    data = process(data)

    with output_path.open("w") as f:
        json.dump(data, f, indent=2)

    print(f"Written to {output_path}")


if __name__ == "__main__":
    main()
