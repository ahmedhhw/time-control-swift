# Improve App Responsiveness

## Problem

The app is sluggish in several places because every mutation calls `saveTodos()` on the main thread, which blocks until SQLite finishes. Two compounding issues:

1. `saveTodos()` (`TodoViewModel.swift:241`) iterates over **every** task and calls `SQLiteStorage.save()` on each — so any single change causes O(n) DB writes.
2. All DB writes happen synchronously on the main thread — the UI waits for disk I/O before continuing.

The worst hotspot is text fields:
- **Floating window description:** `FloatingTaskWindowView` `onChange(of: descriptionText)` → `updateTaskFields(...)` → `saveTodos()`
- **Floating window notes:** `NotesEditorView` `onChange(of: localNotes)` → `updateNotesFromFloatingWindow(...)` → `saveTodos()`

But the root cause affects the whole app — timer toggles, subtask completion, drag-to-reorder all block the main thread.

---

## Two-layer fix

### Layer 1 — Async writes at the DB layer (SQLiteStorage)

Replace `SQLiteStorage.save(_:)` (which calls `dbQueue.write`, blocking) with an async variant using GRDB's built-in `asyncWrite`:

```swift
// SQLiteStorage.swift

// Existing sync write — keep for termination flush only
func save(_ task: TodoItem) throws {
    try dbQueue.write { db in
        try upsertTask(task, db: db)
    }
}

// New async write — use everywhere else
func saveAsync(_ task: TodoItem) {
    let snapshot = task
    dbQueue.asyncWrite({ db in
        try self.upsertTask(snapshot, db: db)
    }, completion: { _, _ in })
}
```

`dbQueue.asyncWrite` is GRDB's own mechanism — it enqueues the write on GRDB's internal serial writer queue and returns immediately. No custom `DispatchQueue` needed; GRDB already serialises all writes internally. The main thread never blocks.

The `let snapshot = task` capture is required: `TodoItem` is a struct so this is a value copy, safe to use off the main thread.

The sync `save(_:)` is kept for one callsite only: `pauseRunningTaskForTermination`, which runs just before the process exits and must complete before returning.

### Layer 2 — Fix O(n) write amplification at the ViewModel layer (TodoViewModel)

`saveTodos()` saves every task on every mutation. Replace it with two targeted helpers:

```swift
// TodoViewModel.swift

// Single-task save — for mutations that only affect one task
private func saveTask(_ task: TodoItem) {
    sqliteStorage?.saveAsync(task)
    // fallback for tests/JSON mode:
    // TodoStorage.save(todos: todos, ..., to: storageURL)
}

// Bulk save — only for mutations that reindex all tasks (add, delete, reorder)
private func saveAllTasks() {
    guard let storage = sqliteStorage else {
        TodoStorage.save(todos: todos, notificationRecords: NotificationStore.shared.records, to: storageURL)
        return
    }
    let snapshot = todos
    for task in snapshot {
        storage.saveAsync(task)
    }
    TodoStorage.saveNotificationRecords(NotificationStore.shared.records)
}
```

### Callsite changes in TodoViewModel

| Callsite | Change |
|---|---|
| `addTodo()` | `saveTodos()` → `saveAllTasks()` (new index assigned) |
| `performDeleteTodo()` | `saveTodos()` → `saveAllTasks()` (reindex) |
| `moveTodo()` | `saveTodos()` → `saveAllTasks()` (reindex) |
| `switchToTask()` | `saveTodos()` → `saveAllTasks()` (stopped + started task both change) |
| `createTask()` | `saveTodos()` → `saveAllTasks()` |
| `toggleTodo()` | `saveTodos()` → `saveTask(todos[index])` |
| `toggleTimer()` | `saveTodos()` → `saveTask(todos[index])` |
| `toggleSubtask()` | `saveTodos()` → `saveTask(todos[todoIndex])` |
| `toggleSubtaskTimer()` | `saveTodos()` → `saveTask(todos[todoIndex])` |
| `addSubtask()` | `saveTodos()` → `saveTask(todos[index])` |
| `performDeleteSubtask()` | `saveTodos()` → `saveTask(todos[todoIndex])` |
| `pauseTask()` | `saveTodos()` → `saveTask(todos[todoIndex])` |
| `resumeTask()` | `saveTodos()` → `saveTask(todos[todoIndex])` |
| `setReminder()` | `saveTodos()` → `saveTask(todos[idx])` |
| `setActiveNotification()` | `saveTodos()` → `saveTask(todos[idx])` |
| `updateTaskFields()` | keep debounce, replace inner `storage.save` with `storage.saveAsync` |
| `updateNotesFromFloatingWindow()` | keep debounce, replace inner `storage.save` with `storage.saveAsync` |
| `pauseRunningTaskForTermination()` | keep `storage.save` (sync) — must complete before process exits |
| All `FromFloatingWindow` variants | same rules as their non-floating counterparts above |

### Debounce on text fields

The existing 400ms debounce on `updateTaskFields` and `updateNotesFromFloatingWindow` is kept. With async writes it's no longer needed for main-thread relief, but it still usefully reduces write frequency during fast typing. No change needed there.

---

## TDD Plan

### Phase 1 — `saveAsync` on SQLiteStorage
**Write tests first:**
- `saveAsync` returns before the DB write completes (call returns in < 1ms; task not yet in DB at return time)
- Task is in DB after draining the write queue (use `dbQueue.write {}` as a barrier to wait)
- Two rapid `saveAsync` calls for the same task: DB ends up with the second version (serial queue preserves order)
- `save` (sync) still works correctly and is used as the flush path in tests

**Then implement:**
- Add `saveAsync(_:)` to `SQLiteStorage`
- Keep existing `save(_:)` unchanged

---

### Phase 2 — `saveTask` and `saveAllTasks` in TodoViewModel
**Write tests first:**
- After `saveTask`, task is persisted after queue drains (barrier check)
- `saveAllTasks` snapshot is taken at call time — mutations to `todos` after the call do not corrupt the in-flight writes
- `saveAllTasks` followed by `saveTask` for the same task: DB ends up with the `saveTask` version (ordering preserved)

**Then implement:**
- Add `saveTask(_:)` and `saveAllTasks()` to `TodoViewModel`
- Replace `saveTodos()` in `addTodo()` and `performDeleteTodo()` as a proof-of-concept

---

### Phase 3 — Convert all callsites
**Write tests first (per method):**
- After `toggleTimer` starts a task, `lastStartTime` is persisted to DB
- After `toggleSubtask` completes a subtask, `isCompleted = true` is in DB
- After `pauseTask`, `lastStartTime = nil` is in DB
- After `resumeTask`, `lastStartTime` is set in DB
- After `moveTodo`, all task indices are correct in DB

**Then implement:**
- Sweep all remaining `saveTodos()` callsites per the table above

---

### Phase 4 — Termination flush
**Write tests first:**
- `pauseRunningTaskForTermination` completes synchronously — DB contains paused state before function returns
- If no task is running, it is a no-op

**Then implement:**
- Verify `pauseRunningTaskForTermination` uses `storage.save` (sync) — no change needed if already correct

---

## Expected outcome

- Main thread is never blocked by SQLite — one change in `SQLiteStorage` fixes it for the entire app automatically
- O(n) write amplification eliminated — single-task mutations write one row, not all rows
- Text fields feel like native editing
- Timer toggles, subtask completion, drag-to-reorder are instant from the user's perspective
- No data loss risk: writes fire immediately (not deferred), GRDB's serial queue preserves ordering, termination flush ensures clean exit state
