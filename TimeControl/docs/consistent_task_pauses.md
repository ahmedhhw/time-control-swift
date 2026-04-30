# Consistent Task Pauses — Investigation

This document captures the high-level findings from auditing the pause/session-stop flows in `TodoViewModel` after observing two recurring issues:

1. Subtasks sometimes keep "running" (`lastStartTime != nil`) after their parent task is paused.
2. Some `TaskSession` records on tasks and subtasks end up with `stoppedAt == nil` (no end date).

The two symptoms share a single root cause: the work of pausing — clearing `lastStartTime`, accumulating `totalTimeSpent`, and closing the open `TaskSession` via `stopSession` / `stopSubtaskSession` — is not centralized. It is hand-inlined in many code paths across `TodoViewModel`, and the paths are inconsistent. Some forget to walk subtasks, some forget to close the session record, and some clear running state without doing either.

## How a "correct" pause looks

A complete pause of a running task (or subtask) is a 3-step block that must run atomically together:

1. `stopSession(...)` / `stopSubtaskSession(...)` — closes the trailing open `TaskSession` by setting `stoppedAt = now`.
2. `totalTimeSpent += now - lastStartTime` — accumulates elapsed time onto the rollup counter.
3. `lastStartTime = nil` — clears the running flag.

When a parent task pauses, that block must additionally be applied to **every running subtask under it**, plus the countdown bookkeeping (`countdownElapsedAtPause`, `countdownStartTime`).

This pattern is repeated by hand in roughly a dozen places ([TodoViewModel.swift](../TimeControl/ViewModels/TodoViewModel.swift)). Wherever a path skips part of the block, it produces one of the two reported symptoms.

## Issue 1 — Subtasks not paused with their parent

Paths that pause a parent task **without** iterating its subtasks to pause them:

- [TodoViewModel.swift:1090-1104](../TimeControl/ViewModels/TodoViewModel.swift#L1090-L1104) — `createTask(switchToIt:)`. When a new task is created with switch-to-it, the previously running task gets `stopSession` + `lastStartTime = nil`, but there is no `for i in subtasks` loop. Any running subtask on the previous task is orphaned: `lastStartTime` stays set, its session stays open. This is the most likely culprit for "subtask keeps running after parent paused".
- [TodoViewModel.swift:1209-1242](../TimeControl/ViewModels/TodoViewModel.swift#L1209-L1242) — `toggleSubtaskTimerFromFloatingWindow` does not have the `guard todos[todoIndex].isRunning` check that its non-floating sibling [`toggleSubtaskTimer`](../TimeControl/ViewModels/TodoViewModel.swift#L457-L502) enforces. From the floating window a subtask can be started while the parent is paused, which leaves the model in a state the rest of the code does not expect (running subtask under paused parent).

By contrast, the paths that **do** correctly cascade the pause to subtasks are: `pauseTask` ([:856](../TimeControl/ViewModels/TodoViewModel.swift#L856)), `pauseRunningTaskForTermination` ([:892](../TimeControl/ViewModels/TodoViewModel.swift#L892)), `toggleTimer` (both branches, [:379](../TimeControl/ViewModels/TodoViewModel.swift#L379) and [:406](../TimeControl/ViewModels/TodoViewModel.swift#L406)), `switchToTask` ([:315](../TimeControl/ViewModels/TodoViewModel.swift#L315)), `toggleTodo` ([:212](../TimeControl/ViewModels/TodoViewModel.swift#L212)), `completeTaskFromFloatingWindow` ([:1286](../TimeControl/ViewModels/TodoViewModel.swift#L1286)), `sanitizeOrphanedRunningState` ([:926](../TimeControl/ViewModels/TodoViewModel.swift#L926)). The fact that *most* paths do this and one (`createTask`) does not is exactly the inconsistency we are seeing.

## Issue 2 — Sessions with no `stoppedAt`

A `TaskSession` is appended on `startSession` / `startSubtaskSession` and is supposed to be closed by the matching `stopSession` / `stopSubtaskSession`, which writes `stoppedAt = now`. There are several paths that produce a session with no end date:

### 2a. Deletes that don't close the open session

- [TodoViewModel.swift:255-270](../TimeControl/ViewModels/TodoViewModel.swift#L255-L270) — `performDeleteTodo` clears `runningTaskId` and removes the task. If the task was running, its trailing session is left with `stoppedAt = nil` until the row is deleted — but in practice the task row is also deleted, so this is benign for tasks themselves. However, **subtasks of that running task that were also running** are dropped along with the task without ever being closed; if any data path later resurrects them (export, history rendering against a stale snapshot, partial restore) those open sessions surface.
- [TodoViewModel.swift:720-731](../TimeControl/ViewModels/TodoViewModel.swift#L720-L731) — `performDeleteSubtask` removes a subtask without first checking `isRunning` and closing its session. If a user deletes the currently running subtask, its open session goes away with the row but the parent task's accounting is now mismatched (the parent is still running, but the subtask whose session was its source of truth is gone).
- [TodoViewModel.swift:1199-1207](../TimeControl/ViewModels/TodoViewModel.swift#L1199-L1207) — `deleteSubtaskFromFloatingWindow` has the same issue.

### 2b. Orphaned state on app crash / hard quit

If the app is force-killed (not the orderly `willTerminateNotification` path), no pause runs. On next launch, `sanitizeOrphanedRunningState` ([:910](../TimeControl/ViewModels/TodoViewModel.swift#L910)) tries to clean up — it walks all tasks and subtasks, calls `stopSession` / `stopSubtaskSession`, and clears `lastStartTime`. The intent is good, but two things go wrong:

- The `stoppedAt` it writes is "now" at next launch, not the moment the app actually died. So the session covers the entire app-down interval, inflating `totalTimeSpent`.
- The 30-second discard rule in `stopSession` / `stopSubtaskSession` ([:634](../TimeControl/ViewModels/TodoViewModel.swift#L634), [:650](../TimeControl/ViewModels/TodoViewModel.swift#L650)) deletes the session entirely if it appears to be < 30 s. After a fast crash this can quietly drop short real sessions.

### 2c. Entire-session deletion masquerading as "no end date"

The `stopSession` / `stopSubtaskSession` helpers do not unconditionally write `stoppedAt`. If the session is younger than 30 seconds they `removeLast()` the session entirely:

```swift
if now - todos[todoIndex].sessions[last].startedAt < 30 {
    todos[todoIndex].sessions.removeLast()
} else {
    todos[todoIndex].sessions[last].stoppedAt = now
}
```

This is a deliberate de-bounce to keep accidental tap-and-pause noise out of history, but it interacts badly with the inconsistent paths above: any path that updates `totalTimeSpent` and then calls `stopSession` for a < 30 s session will keep the time on the rollup but discard the audit row from `sessions`. Reports that read `sessions` (and not `totalTimeSpent`) will under-count, which can read as "missing session" rather than "missing end date" depending on how the consumer renders it.

### 2d. The ordering hazard

Several blocks read like this:

```swift
stopSubtaskSession(todoIndex: i, subtaskIndex: j)            // (1)
if let startTime = todos[i].subtasks[j].lastStartTime {       // (2)
    todos[i].subtasks[j].totalTimeSpent += now - startTime    // (3)
}
todos[i].subtasks[j].lastStartTime = nil                      // (4)
```

This is correct *as written* because step 1 only mutates the `sessions` array and step 2 still reads `lastStartTime`. But the ordering is fragile: if anyone refactors `stopSubtaskSession` to also clear `lastStartTime`, step 3 silently becomes a no-op and `totalTimeSpent` stops accumulating on pause. Worth knowing when reading the code.

## Why this happened

The pause logic was duplicated across every entry point that can stop a timer (manual pause, task switch, completion, deletion, app-quit, sleep, floating-window equivalents of all of the above). There is no single `pauseTaskAndSubtasks(todoIndex:)` helper — instead every caller open-codes the 3-step block plus the subtask loop plus the countdown bookkeeping. With ~10 call sites, drift was inevitable.

## Suggested direction (high level — not implementing)

1. Extract a single `pauseTaskInternal(todoIndex:)` helper that does: stop session, accumulate totalTimeSpent, clear lastStartTime, walk subtasks doing the same, handle countdown bookkeeping. Call it from every site that currently inlines this block (`pauseTask`, `pauseRunningTaskForTermination`, `toggleTimer`, `switchToTask`, `toggleTodo`, `completeTaskFromFloatingWindow`, the missing `createTask` path, `sanitizeOrphanedRunningState`). This eliminates Issue 1 by construction.
2. Add the parent-running guard to `toggleSubtaskTimerFromFloatingWindow` so subtasks cannot start under a paused parent.
3. In the delete paths (`performDeleteTodo`, `performDeleteSubtask`, `deleteSubtaskFromFloatingWindow`), pause first if running, then delete. Even though the row is going away, this keeps the running-state invariant clean and stops the parent from being left in an odd state when a running child is removed.
4. Reconsider the 30-second discard rule, or at least make it explicit in the data model (e.g. a "discarded < 30 s" outcome) so consumers don't read a missing session as a missing `stoppedAt`.
5. For the crash-recovery path, persist a `lastSeenAt` timestamp on each tick so `sanitizeOrphanedRunningState` can close orphaned sessions at the last-seen time rather than at next-launch time.
