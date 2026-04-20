# JSON → SQLite Migration

## Difficulty: Medium

The app currently stores everything in `~/Documents/todos.json` via `TodoStorage.swift` using `JSONSerialization`. The data model is well-understood, so migration is mostly mechanical.

## What needs to change

**Schema — 4 tables:**

| Table | Notes |
|---|---|
| `tasks` | ~20 columns, direct 1:1 mapping from TodoItem fields |
| `subtasks` | `task_id` FK, 6 columns |
| `task_sessions` | `task_id` FK — the nested `sessions` array becomes rows |
| `subtask_sessions` | `subtask_id` FK — same decomposition |

Notification records can stay as JSON (they're already separate and ephemeral).

**Code changes:**
- Rewrite `TodoStorage.swift` (~200 lines) to use SQLite instead of JSON read/write
- Add schema creation + migration logic (version it from day one)
- `TodoItem`, `Subtask`, `TaskSession` structs need no changes — only the serialization layer changes

## Recommended approach

Use **GRDB.swift** (via Swift Package Manager). It wraps SQLite with a Swift-native API, supports `Codable`-style record types, and handles migrations cleanly. Avoids the overhead of Core Data while being much safer than raw SQLite calls.

**DB location:** `~/Documents/TimeControl/timecontrol.db` — storing it in `~/Documents/` ensures the same durability as the current `todos.json`. It survives app updates, reinstalls, and even delete+reinstall since `~/Documents/` is user data and is never touched by macOS during app removal.

## Effort estimate

| Phase | Est. time |
|---|---|
| Add GRDB dependency + define schema | 1–2 hrs |
| Rewrite save/load in TodoStorage | 3–4 hrs |
| One-time migration from existing todos.json | 1 hr |
| Testing + edge cases | 2–3 hrs |

**Total: ~1 day of focused work.** The main risk is getting the one-time migration right so existing user data isn't lost on first launch after the update.

## One-time data migration from todos.json

Runs once on first launch after the update:

1. Check if `~/Documents/todos.json` exists
2. If yes, load it using the existing JSON load code (kept temporarily for this purpose)
3. Insert all tasks, subtasks, and sessions into the new SQLite DB
4. Rename `todos.json` → `todos.json.bak` — do not delete it (safety net for the user)
5. All subsequent launches skip this step entirely

The old JSON load code can be removed in a later cleanup once the migration has been live for a while.

## TDD Implementation Plan

### Phase 1 — GRDB setup + schema
**Write tests first:**
- DB file is created at `~/Documents/TimeControl/timecontrol.db` on first init
- All 4 tables exist with correct columns after schema creation
- Schema migration runs without error on a fresh DB

**Then implement:**
- Add GRDB.swift via SPM
- Create `SQLiteStorage.swift` with DB init + `DatabaseMigrator` defining schema v1

---

### Phase 2 — Save a task
**Write tests first:**
- Saving a `TodoItem` inserts one row in `tasks`
- Saving a task with 2 subtasks inserts 2 rows in `subtasks` with correct `task_id`
- Saving a task with sessions inserts rows in `task_sessions`
- Saving a subtask with sessions inserts rows in `subtask_sessions`
- Saving the same task twice (upsert) does not create duplicates

**Then implement:**
- `save(_ task: TodoItem)` — upserts tasks, subtasks, sessions

---

### Phase 3 — Load tasks
**Write tests first:**
- Loading returns the same `TodoItem` that was saved (all fields round-trip correctly)
- Subtasks are loaded and attached to the correct parent task
- Sessions are loaded and attached to the correct task/subtask
- Tasks are returned sorted by `index`
- Loading from an empty DB returns `[]`

**Then implement:**
- `load() -> [TodoItem]` — joins all 4 tables and reconstructs the object graph

---

### Phase 4 — Delete a task
**Write tests first:**
- Deleting a task removes its row from `tasks`
- Deleting a task also removes its subtasks and sessions (cascade)
- Deleting a task removes its subtasks' sessions

**Then implement:**
- `delete(_ taskId: UUID)` — cascading delete across all 4 tables

---

### Phase 5 — JSON migration
**Write tests first:**
- Running migration with a valid `todos.json` populates the DB with correct task count
- All fields (including sessions and subtasks) are preserved after migration
- After migration, `todos.json` is renamed to `todos.json.bak`
- Running migration a second time (bak already exists, no json) is a no-op
- A task with a running `lastStartTime` is migrated correctly

**Then implement:**
- `migrateFromJSONIfNeeded()` — load JSON using legacy code, insert into DB, rename file

---

### Phase 6 — Swap in production
- Replace `TodoStorage` calls in `TodoViewModel` with `SQLiteStorage`
- Run full app and verify existing JSON data migrates on first launch
- Delete legacy JSON load/save code once confirmed stable

## Main risks

- `lastStartTime` and in-progress sessions (task running when app closes) must be recovered correctly
- `index` ordering must be preserved exactly — it drives the UI sort
- `reminderDate` / `hasActiveNotification` are partially runtime-only; need to decide what to persist
