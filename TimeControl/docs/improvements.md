# TimeControl Improvements

---

## 1. Collapsed Task Row — Contextual Action Menu

### Problem
In collapsed mode, action buttons (play, delete, etc.) clutter the row. The current layout crowds the dropdown arrow.

### Design Mockup

**Current (collapsed):**
```
┌──────────────────────────────────────────────────────┐
│ ▶  Task Name                    [▶][✓][🗑] [▼]       │
└──────────────────────────────────────────────────────┘
```

**Proposed (collapsed, idle):**
```
┌──────────────────────────────────────────────────────┐
│ ▶  Task Name                              [☰]  [▼]   │
└──────────────────────────────────────────────────────┘
```

**Proposed (collapsed, menu open — inline popover to left of ☰):**
```
┌──────────────────────────────────────────────────────┐
│ ▶  Task Name          [▶ Start][✓ Done][🗑 Delete] [☰][▼] │
└──────────────────────────────────────────────────────┘
```

- `☰` icon (or book icon) triggers a horizontal button strip with icon + short label
- Strip slides in from the right or appears as a popover
- Tapping outside or pressing `☰` again dismisses it

### TDD Plan

**Phase 1 — State**
- Write: `TodoRow` has `@State var showActions: Bool`
- Test: toggling `showActions` shows/hides the action strip
- Test: action strip contains Start, Done, Delete buttons with labels
- Implement: add state + conditional rendering

**Phase 2 — Tap-outside dismiss**
- Test: tapping outside the action strip sets `showActions = false`
- Implement: overlay with `.onTapGesture { showActions = false }`

**Phase 3 — Running-task state**
- Test: when task is running, Start button shows "Pause" label
- Test: when task is completed, Done button shows "Undo" label
- Implement: computed label strings based on task state

---

## 2. Keep Floating Window Open on Lock / Sleep — Only Pause Timer

### Problem
When the Mac locks or sleeps, the floating Current Task window is hidden. It should stay open; only the timer should pause.

### Design Mockup

**Floating window state on wake:**
```
┌─────────────────────────────────┐
│ Current Task              [×]   │
│─────────────────────────────────│
│ ⏸  Task Name                    │
│     00:42:17  (paused on sleep) │
│                                 │
│  [▶ Resume]                     │
└─────────────────────────────────┘
```
- Window remains visible after wake
- Timer is paused (not zeroed)
- Resume button is present (addresses Issue 3 as well)

### TDD Plan

**Phase 1 — Observe screen/sleep notifications**
- Test: `AppDelegate` registers for `NSWorkspace.willSleepNotification` and `NSWorkspace.screensDidLockNotification`
- Test: receiving `willSleepNotification` calls `viewModel.pauseRunningTask(keepWindowOpen: true)`
- Implement: add observers in `AppDelegate.applicationDidFinishLaunching`

**Phase 2 — Window visibility on lock**
- Test: `FloatingWindowManager` does NOT call `closeFloatingWindow()` when sleep/lock notification fires
- Test: after wake (`NSWorkspace.didWakeNotification`), floating window is still key and visible
- Implement: remove any `closeFloatingWindow()` call triggered by sleep/lock path

**Phase 3 — Resume button always present post-sleep**
- Test: after `pauseRunningTask(keepWindowOpen: true)`, `FloatingTaskWindowView` shows Resume button
- Test: Resume button calls `viewModel.resumeTask(_:)`
- Implement: ensure Resume button is rendered when `localTask.lastStartTime == nil && !localTask.isCompleted`

---

## 3. Resume Button Missing on Wake (Bug Fix)

### Problem
On one machine the resume button does not appear in the popup after waking from sleep. Root cause: the wake notification arrives before `FloatingWindowManager` has synced the paused task state, so `localTask` still shows `isRunning = true` and the Resume button is hidden.

### Design Mockup
Same as Issue 2 — Resume button visible after wake.

### TDD Plan

**Phase 1 — Reproduce**
- Test: simulate sleep → wake sequence; assert `FloatingTaskWindowView.localTask.lastStartTime == nil` after wake
- Test: `FloatingWindowManager.updateTask(_:)` is called with the paused task before the wake notification fires any UI update

**Phase 2 — Fix sync ordering**
- Test: `pauseRunningTask` updates `FloatingWindowManager` synchronously before returning
- Implement: ensure `FloatingWindowManager.shared.updateTask(pausedTask)` is called inside `pauseTask()` before any async dispatch

**Phase 3 — Regression**
- Test: Resume button is visible in `FloatingTaskWindowView` when `localTask.lastStartTime == nil && !localTask.isCompleted`
- Test: Resume button is hidden when task is running

---

## 4. Weekly Hours in History / Calendar View

### Problem
The history view shows per-day data but no weekly aggregate, making it hard to see total work per week.

### Design Mockup

**Calendar grid with weekly totals (right column):**
```
┌────────────────────────────────────────────────────────┐
│  April 2026                                    [< >]   │
│────────────────────────────────────────────────────────│
│  Mon   Tue   Wed   Thu   Fri   Sat   Sun  │  Week      │
│──────────────────────────────────────────────────────  │
│   6     7     8     9    10    11    12   │  18h 30m   │
│  3h    4h   2h30  5h    4h     -     -   │            │
│──────────────────────────────────────────────────────  │
│  13    14    15    16    17    18    19   │  22h 15m   │
│  4h   3h30   5h   4h45  5h     -     -   │            │
└────────────────────────────────────────────────────────┘
```

- Weekly total shown in a right-hand "Week" column
- Format: `Xh Ym` (omit hours if 0, omit minutes if 0)
- Tapping the week total filters the detail list to that week

### TDD Plan

**Phase 1 — Weekly aggregation logic**
- Test: `weeklyTotal(for:sessions:)` sums all session durations in the Mon–Sun window containing the given date
- Test: sessions spanning midnight are counted in the day they started
- Test: returns `0` if no sessions in the week
- Test: weeks correctly split at Sunday→Monday boundary
- Implement: pure function in `TimeFormatter` or a new `HistoryViewModel`

**Phase 2 — Calendar view model**
- Test: `HistoryViewModel.weeklyTotals` returns one entry per week in the displayed month
- Test: partial weeks (month starts mid-week) are correctly bounded
- Implement: `weeklyTotals: [WeekRow]` computed property

**Phase 3 — UI**
- Test: calendar grid renders a "Week" column header
- Test: each week row cell displays the formatted total
- Test: tapping a week row sets `selectedWeek` and filters the session list
- Implement: add column to existing calendar `Grid` or `HStack` layout

---

## 5. Don't Resume Timer When Clicking Time on a Completed Task (Collapsed Mode)

### Problem
In collapsed mode, clicking the time display on a **completed** task starts the timer, which is unintended. A finished task should not be resumable this way.

### Design Mockup

**Collapsed row — completed task:**
```
┌──────────────────────────────────────────────────────┐
│ ✓  Completed Task Name           1h 23m 45s   [☰][▼] │
└──────────────────────────────────────────────────────┘
         ↑ click → no-op (cursor: default)
```

**Collapsed row — active task:**
```
┌──────────────────────────────────────────────────────┐
│ ▶  Running Task Name             0h 42m 17s   [☰][▼] │
└──────────────────────────────────────────────────────┘
         ↑ click → pause timer
```

### TDD Plan

**Phase 1 — Guard in tap handler**
- Test: tapping the time display on a completed task does NOT call `viewModel.toggleTimer(_:)`
- Test: tapping the time display on an incomplete, non-running task calls `viewModel.toggleTimer(_:)` (starts timer)
- Test: tapping the time display on a running task calls `viewModel.toggleTimer(_:)` (pauses timer)
- Implement: in `TodoRow`, wrap the time-tap gesture with `guard !todo.isCompleted else { return }`

**Phase 2 — Cursor feedback**
- Test: time label has `.onHover` cursor set to `.arrow` when task is completed
- Test: time label has `.onHover` cursor set to `.pointingHand` when task is not completed
- Implement: `.onHover { hovering in NSCursor... }` conditional on `todo.isCompleted`

**Phase 3 — Regression**
- Test: completing a running task via the Done button pauses the timer AND disables the time-tap gesture
- Test: un-completing a task (Undo) re-enables the time-tap gesture
