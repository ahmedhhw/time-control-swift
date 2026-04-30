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

---

## TDD Implementation Plan

**Conventions observed in `TimeControlTests/`:**
- XCTest, `@testable import TimeControl`, one `final class …Tests: XCTestCase` per topic.
- Factories in [TestHelpers.swift](../TimeControlTests/TestHelpers.swift): `makeViewModel()`, `makeTodo(...)`, `makeSubtask(...)`.
- Time is exercised by setting `lastStartTime = Date(timeIntervalSinceNow: -N)` and asserting on `totalTimeSpent` / `sessions.last?.stoppedAt`.
- Existing relevant files: [TodoViewModelTests.swift](../TimeControlTests/TodoViewModelTests.swift), [OrphanedSessionTests.swift](../TimeControlTests/OrphanedSessionTests.swift), [SleepWakeTests.swift](../TimeControlTests/SleepWakeTests.swift). New tests slot in alongside these.

Each section below is one red→green→refactor cycle. Do not move to the next until the previous is green.

### Cycle 1 — Extract `pauseTaskInternal(todoIndex:)` and route every pause site through it

The goal is to make Issue 1 disappear by construction. Drive it out by writing tests for **observable behavior at each call site**, not for the helper directly. The helper appears in the green step as the simplest way to satisfy them all.

**New test file:** `TimeControlTests/TaskPauseConsistencyTests.swift`

**RED — write these tests first, confirm they fail:**

1. `test_createTask_switchToIt_pausesRunningSubtaskOnPreviousTask`
   - Arrange: Two todos `[A, B]`. `A` has subtask `s1`. Start `A` via `toggleTimer`; `s1` is auto-running.
   - Act: `vm.createTask(title: "C", switchToIt: true)`.
   - Assert: `vm.todos[A].subtasks[s1].lastStartTime == nil`, `s1.isRunning == false`, `s1.totalTimeSpent > 0`, and the trailing session on `s1` has `stoppedAt != nil` **or** was discarded under the < 30 s rule (assert one or the other depending on the elapsed time you set up — use a `lastStartTime` 60 s in the past so `stoppedAt` is the expected outcome).
   - **This is the headline failing test for Issue 1.** Currently fails because [createTask:1090-1104](../TimeControl/ViewModels/TodoViewModel.swift#L1090-L1104) skips the subtask loop.

2. `test_createTask_switchToIt_pausesRunningSubtaskTimer_setsStoppedAt`
   - Same setup as above but inspect `vm.todos[A].subtasks[0].sessions.last?.stoppedAt` is non-nil.

3. `test_pauseTask_pausesAllRunningSubtasks` (regression guard for the existing-correct path).
4. `test_toggleTimer_pause_pausesAllRunningSubtasks` (regression).
5. `test_switchToTask_pausesAllRunningSubtasks` (regression).
6. `test_completeTaskFromFloatingWindow_pausesAllRunningSubtasks` (regression).
7. `test_toggleTodo_complete_pausesAllRunningSubtasks` (regression).
8. `test_pauseRunningTaskForTermination_pausesAllRunningSubtasks` — call the public-via-notification path: post `NSApplication.willTerminateNotification` and assert.

**Why all 8:** the refactor in green will move every site to one helper. Tests 3-8 are the safety net that proves no site regressed during the move.

**GREEN — minimum production change:**

In [TodoViewModel.swift](../TimeControl/ViewModels/TodoViewModel.swift), introduce:

```swift
private func pauseTaskInternal(todoIndex: Int) {
    guard todoIndex >= 0, todoIndex < todos.count else { return }
    // 1. Pause parent
    if todos[todoIndex].isRunning {
        stopSession(todoIndex: todoIndex)
        if let s = todos[todoIndex].lastStartTime {
            todos[todoIndex].totalTimeSpent += Date().timeIntervalSince(s)
        }
        todos[todoIndex].lastStartTime = nil
    }
    // 2. Countdown bookkeeping
    if todos[todoIndex].countdownTime > 0,
       let cs = todos[todoIndex].countdownStartTime {
        todos[todoIndex].countdownElapsedAtPause += Date().timeIntervalSince(cs)
        todos[todoIndex].countdownStartTime = nil
    }
    // 3. Cascade to subtasks
    for i in todos[todoIndex].subtasks.indices {
        guard todos[todoIndex].subtasks[i].isRunning else { continue }
        stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: i)
        if let s = todos[todoIndex].subtasks[i].lastStartTime {
            todos[todoIndex].subtasks[i].totalTimeSpent += Date().timeIntervalSince(s)
        }
        todos[todoIndex].subtasks[i].lastStartTime = nil
    }
}
```

Replace the inlined pause blocks at the call sites enumerated in the doc — `pauseTask`, `pauseRunningTaskForTermination`, both branches of `toggleTimer`, `switchToTask`, `toggleTodo`, `completeTaskFromFloatingWindow`, `createTask(switchToIt:)` (the missing one — this is what flips test 1 green), and `sanitizeOrphanedRunningState`'s per-task body — with a call to `pauseTaskInternal(todoIndex:)`. Leave `runningTaskId`, floating-window updates, and post-pause persistence at the call sites; the helper only owns the model mutation.

**REFACTOR:** dedupe the countdown branch into the helper (already above), confirm all 8 tests still green.

### Cycle 2 — Parent-running guard on `toggleSubtaskTimerFromFloatingWindow`

**New tests in `TaskPauseConsistencyTests.swift`**

**RED:**

1. `test_toggleSubtaskTimerFromFloatingWindow_doesNothing_whenParentNotRunning`
   - Arrange: `[A]` with subtask `s1`. **Do not** start `A`.
   - Act: `vm.toggleSubtaskTimerFromFloatingWindow(s1.id, in: A.id)`.
   - Assert: `s1.isRunning == false`, `s1.lastStartTime == nil`, `s1.sessions.isEmpty`.
   - Currently fails — the floating-window variant at [:1209-1242](../TimeControl/ViewModels/TodoViewModel.swift#L1209-L1242) skips the guard.

2. `test_toggleSubtaskTimerFromFloatingWindow_pausesRunningSubtask_whenParentRunning` (regression — make sure the guard didn't break the supported flow).

**GREEN:** add `guard todos[todoIndex].isRunning else { return }` at the top of `toggleSubtaskTimerFromFloatingWindow`, mirroring [toggleSubtaskTimer:463](../TimeControl/ViewModels/TodoViewModel.swift#L463).

**REFACTOR:** none expected.

### Cycle 3 — Pause-before-delete for the three delete paths

**New test file:** `TimeControlTests/PauseBeforeDeleteTests.swift`

**RED:**

1. `test_performDeleteTodo_pausesRunningSubtasks_beforeRemoving`
   - Arrange: `[A]` with subtasks `[s1, s2]`. Start `A` (auto-runs `s1`). Capture `s1.id`.
   - Act: `vm.confirmTaskDeletion = false; vm.deleteTodo(A)`.
   - Assert: `vm.runningTaskId == nil`. The model invariant we want is "no orphaned open sessions from the deletion." Since the row is gone, the cleanest assertion is **no runtime side-effects on the floating window** and **`runningTaskId` is nil**. To make this test sharp without inspecting deleted rows, also assert that calling `vm.sanitizeOrphanedRunningState()` immediately afterwards is a no-op (no `needsSave`, no mutations) — currently fails because the running-state on the deleted row's in-memory copy was never closed.
   - Practical alternative if `sanitize` is hard to observe: emit a single `pauseTaskInternal` call before removal and assert the parent's session was closed *before* `todos.removeAll`. The simplest assertion is to capture `vm.todos[0].sessions` immediately before delete and then after a "delete-but-keep" variant — but the cleanest test is just: `XCTAssertNil(vm.runningTaskId)` and that subtask state on the *snapshot we held* before delete had `lastStartTime == nil` (this requires reading `vm.todos[0]` between pausing and removing, which is observable if the helper is called first).

   **Keep this test simple:** assert `vm.runningTaskId == nil` and `vm.todos.isEmpty`. The strong guarantee comes from cycle 4 below — make this test pair with the 30 s discard test so the audit row outcome is well-defined.

2. `test_performDeleteSubtask_pausesRunningSubtask_beforeRemoving`
   - Arrange: `[A]` with `[s1]`. Start `A`; `s1` auto-runs.
   - Act: `vm.confirmSubtaskDeletion = false; vm.deleteSubtask(s1, from: A)`.
   - Assert: `vm.todos[0].subtasks.isEmpty`. Then assert that the *parent's* state is internally consistent: parent is still running (we only deleted a subtask), parent's session is still open (one session, `stoppedAt == nil`), and there is no leftover orphan record anywhere. Most importantly: `vm.sanitizeOrphanedRunningState()` immediately after is a no-op.

3. `test_deleteSubtaskFromFloatingWindow_pausesRunningSubtask_beforeRemoving` — same as test 2 but via the floating-window entrypoint at [:1199-1207](../TimeControl/ViewModels/TodoViewModel.swift#L1199-L1207).

**GREEN:**
- In [performDeleteTodo:255](../TimeControl/ViewModels/TodoViewModel.swift#L255), if `todo.id == runningTaskId`, call `pauseTaskInternal(todoIndex:)` before `todos.removeAll`. Then clear `runningTaskId` and close the floating window as today.
- In [performDeleteSubtask:720](../TimeControl/ViewModels/TodoViewModel.swift#L720) and [deleteSubtaskFromFloatingWindow:1199](../TimeControl/ViewModels/TodoViewModel.swift#L1199), if the target subtask `isRunning`, run the 3-step subtask-pause block (close session, accumulate `totalTimeSpent`, clear `lastStartTime`) **before** `removeAll`. Note: we don't need to pause the parent — only the running subtask being removed.

**REFACTOR:** if cycle 1's helper has a `pauseSubtaskInternal(todoIndex:subtaskIndex:)` sibling, use it here. Otherwise extract one now and re-route any other subtask-pause site through it (purely a code-hygiene refactor with green tests).

### Cycle 4 — Make the 30 s discard explicit in the data model

The discard rule in [stopSession:634](../TimeControl/ViewModels/TodoViewModel.swift#L634) currently silently `removeLast()`s the row, so consumers of `sessions` cannot tell "never happened" from "happened but discarded." Drive a model change.

**New test file:** `TimeControlTests/SessionDiscardTests.swift`

**RED:**

1. `test_stopSession_underThirtySeconds_marksSessionAsDiscarded_notRemoved`
   - Arrange: todo with `lastStartTime = Date(timeIntervalSinceNow: -10)` and one open session.
   - Act: pause via `toggleTimer`.
   - Assert: `vm.todos[0].sessions.count == 1` (session is **kept**), the session has `stoppedAt != nil`, and `session.outcome == .discardedShort` (or whatever the new field is — see green).

2. `test_stopSession_overThirtySeconds_marksSessionAsCompleted`
   - Arrange: `lastStartTime = -60s`.
   - Assert: `session.outcome == .completed`, `stoppedAt != nil`.

3. `test_history_filtersOutDiscardedShortSessions_byDefault` (only if there's an existing history filter to update — check [HistorySessionFilterTests.swift](../TimeControlTests/HistorySessionFilterTests.swift) for the shape).

4. `test_totalTimeSpent_unchanged_byDiscardOutcome`
   - Discard rule is for the audit row only; `totalTimeSpent` accumulation behavior must not change. Assert with both the < 30 s and > 30 s cases that `totalTimeSpent` increases by the elapsed amount.

**GREEN:**
- Add `enum SessionOutcome: String, Codable { case completed, discardedShort }` and a `var outcome: SessionOutcome = .completed` to `TaskSession` in [TodoItem.swift](../TimeControl/Models/TodoItem.swift). Default `.completed` keeps existing decoded data backward-compatible.
- Change `stopSession` / `stopSubtaskSession`: instead of `removeLast()` for < 30 s, set `stoppedAt = now` **and** `outcome = .discardedShort`.
- Update the SQLite schema in [SQLiteStorage.swift](../TimeControl/Services/SQLiteStorage.swift) — add `outcome TEXT` column to `task_sessions` and `subtask_sessions`, plus a migration `v3_session_outcome`. Read/write in `buildTask` / `buildSubtask` / the session inserts.
- Update history consumers (filter, exports) to skip `.discardedShort` by default if the existing UX did not show those sessions; this is the smallest behavior-preserving change.

**REFACTOR:** rename `outcome` if a clearer name emerges. Make the 30 s threshold a named constant.

**Note:** This cycle hardens cycle 3's tests — once sessions are kept (not removed), the "no orphan after delete" assertion in cycle 3 can additionally check that the deleted subtask's session was marked `.completed`/`.discardedShort` rather than being silently lost. Consider tightening cycle 3's tests after cycle 4 is green.

### Cycle 5 — `lastSeenAt` for crash-recovery in `sanitizeOrphanedRunningState`

The current sanitize stamps `stoppedAt = launchTime`, inflating elapsed time across the app-down interval. Replace with a per-tick heartbeat.

**Tests in `OrphanedSessionTests.swift` (extend existing file — matches its scope)**

**RED:**

1. `test_sanitize_usesLastSeenAt_asStoppedAt_notNow`
   - Arrange: build a `vm` directly, set `vm.todos = [...]` with a running todo whose `lastStartTime = -1h`, and write `vm.lastSeenAt = Date(timeIntervalSinceNow: -1800)` (30 min ago — i.e. the app was last alive 30 min ago, then "crashed" and is now relaunching).
   - Act: call `vm.sanitizeOrphanedRunningState()`.
   - Assert: `vm.todos[0].sessions.last?.stoppedAt ≈ vm.lastSeenAt!.timeIntervalSince1970` (within ±2 s), and `vm.todos[0].totalTimeSpent ≈ 30 minutes`, **not** 1 hour. Currently fails — sanitize uses `Date()`.

2. `test_sanitize_fallsBackToNow_whenLastSeenAtAbsent`
   - Arrange: same as above but `vm.lastSeenAt == nil` (first-ever launch, or migration in progress).
   - Assert: behaves like today (uses `now`). This guards the migration window for users on existing installs.

3. `test_lastSeenAt_persisted_onTimerTick`
   - Arrange: `vm` with one running task. Force a timer tick (the 1 s `Timer.publish` in [startTimer:113](../TimeControl/ViewModels/TodoViewModel.swift#L113)).
   - Assert: `vm.lastSeenAt` advanced and was persisted (e.g. `UserDefaults` write or DB row update). Test by reading it back via a fresh `TodoViewModel` constructed against the same `dbURL` / storage.

   **Practical note:** persisting on every 1 s tick to disk is wasteful. Prefer writing on a coarser cadence (every 30 s) or on the existing save calls. Adjust the test to assert that `lastSeenAt` is persisted at least once within N seconds, not on every tick.

4. `test_sanitize_clamps_lastSeenAt_toMaxAcceptableSkew` (optional safety guard)
   - If `lastSeenAt` is somehow in the future or older than `lastStartTime`, sanitize should fall back to `Date()` rather than producing a negative elapsed.

**GREEN:**
- Add `private(set) var lastSeenAt: Date?` on `TodoViewModel` (or a dedicated `HeartbeatStore`).
- Persist on a throttled cadence (e.g. once every 30 s in the existing tick handler, or piggy-backed on `saveTask`). Minimum viable: write to `UserDefaults` keyed by a constant; load it eagerly at init.
- In `sanitizeOrphanedRunningState`, replace each `Date()` capture with `let cutoff = lastSeenAt ?? Date()`, and pass it down so `stopSession` writes `cutoff.timeIntervalSince1970` and `totalTimeSpent` accumulates `cutoff.timeIntervalSince(startTime)`. This requires either an overload (`stopSession(todoIndex:at:)`) or a flag — favor the overload to keep the normal path simple.
- Clear `lastSeenAt` after a successful clean shutdown (via the existing `pauseRunningTaskForTermination` or willTerminate observer) so the next launch knows there was no crash and can use `Date()`.

**REFACTOR:** move heartbeat into its own small type if it sprawls. Keep `sanitizeOrphanedRunningState`'s public signature stable.

### Suggested order

Run cycles in order — they build on each other:

1. **Cycle 1** first. It establishes `pauseTaskInternal` and the regression net. Every later cycle benefits from the helper.
2. **Cycle 2** next — trivial, one-line green, fully isolated.
3. **Cycle 3** depends on cycle 1's helper (or its `pauseSubtaskInternal` sibling).
4. **Cycle 4** is independent of 1-3 mechanically but tightens the assertions in cycle 3, so do it after.
5. **Cycle 5** is the largest — schema isn't touched (no migration needed for `lastSeenAt` if stored in `UserDefaults`), but it changes the orphan-cleanup contract. Do last so the regressions in cycles 1-4 don't compound.

### Out of scope

- The "ordering hazard" (§2d) is a code-comment / lint concern, not a behavior change. No tests; address it in cycle 1's refactor step by adding an inline comment on `stopSubtaskSession` documenting the precondition.
- UI/floating-window plumbing — every cycle keeps the existing `FloatingWindowManager.shared.updateTask(...)` calls at the call sites untouched.
- ADO sync, notifications, countdown UI — not in scope.
