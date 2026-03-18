# Missing Test Coverage

Estimated current coverage: ~35–40% of public methods have direct unit tests.

---

## TodoViewModel

### Untested methods

| Method | Notes |
|--------|-------|
| `toggleExpanded(_:)` | Expand/collapse a single task |
| `toggleExpandAll()` | Expand/collapse all tasks |
| `renameSubtask(_:in:newTitle:)` | Main window rename |
| `renameSubtaskFromFloatingWindow(_:in:newTitle:)` | Floating window rename |
| `generateExportTextForTask(_:)` | Single-task text export |
| `generateExportTextForAllTasks()` | Bulk text export |
| `pauseTask(_:keepWindowOpen:)` | Pause with window control |
| `resumeTask(_:)` | Resume a paused task |
| `updateTaskFields(id:text:description:notes:dueDate:isAdhoc:fromWho:estimatedTime:)` | Bulk field update |
| `setReminder(_:for:)` | Set reminder date |
| `setActiveNotification(_:for:)` | Activate notification |
| `dismissBell(for:)` | Dismiss notification bell |
| `createTask(title:switchToIt:)` | Create task + optional switch |
| `toggleSubtaskFromFloatingWindow(_:in:)` | Floating window subtask toggle |
| `addSubtaskFromFloatingWindow(to:title:)` | Floating window add subtask |
| `deleteSubtaskFromFloatingWindow(_:from:)` | Floating window delete subtask |
| `toggleSubtaskTimerFromFloatingWindow(_:in:)` | Floating window subtask timer |
| `switchToTask(byId:)` | Switch task by UUID |

### Untested edge cases

- Switching tasks when auto-play is on but the new task has no incomplete subtasks
- Countdown timer behavior across task switches
- Countdown pause/resume — `countdownElapsedAtPause` interaction
- Deleting a task while one of its subtask timers is running
- Renaming a subtask with whitespace-only text
- Mass operations (`MassOperationType`) — enum exists but no operational tests

---

## TimeFormatter

### Untested methods

| Method | Notes |
|--------|-------|
| `formatTimeNoSeconds(_:)` | Omits seconds from output |
| `formatTimeRemaining(_:)` | Days/hours remaining display |
| `formatDueDate(_:)` | Human-readable due date string |

### Untested edge cases

- `formatTime()` at exact boundaries: 0 s, 3600 s (1 h), very large values
- `formatTimeRemaining()` with a negative time interval
- `formatDueDate()` locale variations

---

## NotificationScheduler

### Untested methods

| Method | Notes |
|--------|-------|
| `schedule(_:at:)` | Schedule with an explicit `Date` |
| `rescheduleAll(_:)` | Re-enqueue all pending reminders |
| `startPolling()` | Starts the internal polling timer |
| `tick()` | Per-tick evaluation logic |
| `fire(taskId:taskTitle:)` | Fires the actual notification |

### Untested edge cases

- Reminder missed by < 5 minutes — should still fire
- Reminder date already in the past at scheduling time
- Two reminders firing within the same polling minute
- Timer tolerance (5 s) boundary behaviour

---

## NotificationStore

### Untested methods

| Method | Notes |
|--------|-------|
| `setInitialRecords(_:)` | Bulk-load records on startup |
| `append(_:)` | Append a new `NotificationRecord` |
| `dismiss(taskId:)` | Mark a task's notifications dismissed |
| `onNeedsSave` callback | Callback invoked when store mutates |

### Untested edge cases

- `dismiss(taskId:)` called twice for the same task
- `dismiss(taskId:)` for a task ID that has no records
- `onNeedsSave` actually triggering a persistence write

---

## TodoStorage

### Untested persistence fields

These fields are defined in the model and stored to disk but have no round-trip (save → load) test:

- `countdownTime`
- `countdownStartTime`
- `countdownElapsedAtPause`
- `lastPlayedAt`
- `hasActiveNotification`
- `reminderDate`

### Untested scenarios

- `load()` gracefully handles a JSON file missing optional fields
- Old notification records (> 30 days) are filtered out on load
- File write error handling / recovery
- Corrupted JSON beyond basic try-catch (partial / truncated file)

---

## Models & Enums

### Untested computed properties / enum members

| Item | Notes |
|------|-------|
| `AutoPauseDuration.displayName` | Never asserted in any test |
| `DefaultTimerDuration.displayName` | Never asserted in any test |
| `TodoItem.hasActiveNotification` | Runtime-only; no direct assertion |
| `TodoItem.countdownElapsed` | Edge cases with paused state |
| `DropdownSortOption` (all cases) | Enum exists; no sort tests use it |
| `EditableField` (all 7 cases) | Defined but never exercised |
| `ReminderResponse` (all cases) | Defined but never used in tests |
| `NotificationPayload` struct | Constructed but never explicitly tested |

---

## Summary of Biggest Gaps

1. **Notification system** — scheduling, firing, rescheduling, and store mutations are nearly untested
2. **Export functionality** — both single-task and bulk export methods have zero test coverage
3. **Floating window operations** — 5 dedicated floating-window methods are untested
4. **Countdown timer** — complex pause/resume/persist logic is untested
5. **Task field bulk update** — `updateTaskFields` is entirely untested
6. **TimeFormatter helpers** — 3 of 6 formatting methods are untested
7. **TodoStorage round-trips** — 6 model fields have no persistence tests

---

## Implementation Plan

### Phase 1 — Low-hanging fruit (pure logic, no dependencies)

Target files: `TimeFormattingTests.swift`, new `ModelEnumTests.swift`

- [ ] `TimeFormatter.formatTimeNoSeconds(_:)` — test 0 s, 59 s, 60 s, 3600 s, large values
- [ ] `TimeFormatter.formatTimeRemaining(_:)` — test positive, zero, negative intervals
- [ ] `TimeFormatter.formatDueDate(_:)` — test a fixed date produces expected string
- [ ] `TimeFormatter.formatTime()` boundary values (0 s, exactly 1 h, very large)
- [ ] `AutoPauseDuration.displayName` — assert each case returns a non-empty string
- [ ] `DefaultTimerDuration.displayName` — assert each case returns a non-empty string
- [ ] `TodoItem.hasActiveNotification` — set flag, assert computed property reflects it
- [ ] `TodoItem.countdownElapsed` — test while running vs. paused (`countdownElapsedAtPause`)

### Phase 2 — ViewModel core gaps (state logic)

Target files: `TodoViewModelTests.swift`, `TodoOperationsTests.swift`

- [ ] `pauseTask(_:keepWindowOpen:)` / `resumeTask(_:)` — verify `runningTaskId`, `lastStartTime`, session state
- [ ] `createTask(title:switchToIt: true)` — assert new task becomes running task
- [ ] `updateTaskFields(...)` — update every field, assert model reflects changes
- [ ] `renameSubtask(_:in:newTitle:)` — happy path + whitespace-only input (should be ignored/trimmed)
- [ ] `switchToTask(byId:)` — assert previous task pauses, new task starts
- [ ] `toggleExpanded(_:)` / `toggleExpandAll()` — assert `expandedTodos` set mutates correctly
- [ ] Auto-play on task switch when new task has no incomplete subtasks — assert no subtask timer starts
- [ ] Delete task while subtask timer is running — assert no dangling timer state

### Phase 3 — Floating window operations

Target files: new `FloatingWindowOperationsTests.swift`

- [ ] `toggleSubtaskFromFloatingWindow(_:in:)` — mirrors `toggleSubtask` behaviour
- [ ] `addSubtaskFromFloatingWindow(to:title:)` — subtask appears in task, title matches
- [ ] `deleteSubtaskFromFloatingWindow(_:from:)` — subtask removed, running state cleaned up
- [ ] `toggleSubtaskTimerFromFloatingWindow(_:in:)` — only starts when parent task is running
- [ ] `renameSubtaskFromFloatingWindow(_:in:newTitle:)` — same edge cases as Phase 2 rename

### Phase 4 — Storage round-trips

Target files: `TodoStorageTests.swift`

- [ ] `countdownTime` round-trip (save → load)
- [ ] `countdownStartTime` round-trip
- [ ] `countdownElapsedAtPause` round-trip
- [ ] `lastPlayedAt` round-trip
- [ ] `hasActiveNotification` round-trip
- [ ] `reminderDate` round-trip
- [ ] `load()` with a JSON file missing optional fields — assert no crash, defaults applied
- [ ] Old notification records (> 30 days) pruned on load
- [ ] Corrupted / truncated JSON — assert graceful fallback to empty state

### Phase 5 — Notification system

Target files: new `NotificationStoreTests.swift`, extend `NotificationSchedulerTests.swift`

**NotificationStore**
- [ ] `setInitialRecords(_:)` — records array is populated correctly
- [ ] `append(_:)` — record count increases, content matches
- [ ] `dismiss(taskId:)` — matching records marked dismissed
- [ ] `dismiss(taskId:)` idempotent — calling twice has no extra side-effect
- [ ] `dismiss(taskId:)` for unknown ID — no crash
- [ ] `onNeedsSave` callback fires after `append` and `dismiss`

**NotificationScheduler**
- [ ] `schedule(_:at:)` with a future date — task appears in pending list
- [ ] `rescheduleAll(_:)` — replaces existing schedule with new list
- [ ] `tick()` with a reminder in the past — `fire` is called
- [ ] `tick()` with reminder missed by < 5 min — still fires
- [ ] `tick()` with reminder > 5 min in past — does not fire
- [ ] Two tasks due in the same minute — both fire

### Phase 6 — Export functionality

Target files: new `ExportTests.swift`

- [ ] `generateExportTextForTask(_:)` — output contains task title, subtasks, notes
- [ ] `generateExportTextForTask(_:)` with no subtasks — no crash, reasonable output
- [ ] `generateExportTextForAllTasks()` — output contains all task titles
- [ ] `generateExportTextForAllTasks()` with empty list — returns empty or placeholder string

### Phase 7 — Notification ViewModel integration

Target files: extend `TodoViewModelTests.swift`

- [ ] `setReminder(_:for:)` — `reminderDate` on task updates, scheduler is called
- [ ] `setActiveNotification(_:for:)` — `hasActiveNotification` flips, store reflects change
- [ ] `dismissBell(for:)` — bell state clears, `NotificationStore.dismiss` is invoked
