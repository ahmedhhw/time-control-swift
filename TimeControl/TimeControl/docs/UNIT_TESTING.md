# Unit Testing Guide — TimeControl

## Current State (verified 2026-03-17)

**111 tests · 108 passing · 3 failing**

Test files that exist today:

| File | Status |
|---|---|
| `TodoItemTests.swift` | Passing (equality test already seeds same `id`) |
| `SubtaskTests.swift` | 1 failure — `testSubtaskEqualityWithDifferentContent` |
| `TodoOperationsTests.swift` | Passing — but tests model structs directly, not `TodoViewModel` |
| `TimeFormattingTests.swift` | All passing |
| `TodoStorageTests.swift` | 1 failure + 14 tests hitting real `~/Documents/todos.json` |
| `CompilationTest.swift` | Passing — noise, no real coverage |

Files that do **not** exist yet (need to be created):

- `Helpers/TestHelpers.swift`
- `ViewModel/TodoViewModelTests.swift`
- `ViewModel/FilterSortTests.swift`
- `Models/TaskSessionTests.swift`
- `Services/NotificationSchedulerTests.swift`

---

## The Rule: Tests Must Fail Before They Pass

Every test must be observed failing — for the right reason — before the production code that makes it pass is written. This is non-negotiable.

**Why this matters:** A test that has never been red provides no signal. It may pass because the behaviour already exists, because the assertion is wrong, because the test is testing the wrong thing, or because it can never fail at all. Only a red test proves the assertion is wired to real behaviour.

### The red-green-refactor cycle

```
1. RED    — write the test, run it, confirm it fails with the expected message
2. GREEN  — write the minimum production code to make it pass, run it again
3. REFACTOR — clean up with tests staying green
```

Never skip step 1. Never move to step 2 without seeing the failure.

A compile error is not a red test. The failure must be an assertion failure naming the missing behaviour.

```swift
// Good red — assertion fires because logic doesn't exist yet:
XCTAssertFalse(todo.isRunning)
// → "XCTAssertFalse failed"

// Bad red — test crashes before asserting anything:
vm.toggleTimer(vm.todos[0])  // fatal: index out of range (todos is empty)
```

### Stubs for unimplemented tests

```swift
func testCompletedSubtasks_movedToTopOfCompletedBlock() {
    XCTFail("not implemented yet")
}
```

Do not use empty test bodies — they pass silently.

### Running a single test

```bash
xcodebuild test \
  -scheme TimeControl \
  -destination 'platform=macOS' \
  -only-testing TimeControlTests/TodoViewModelTests/testToggleTimer_onlyOneTaskRunsAtATime
```

---

## Phase 0 — Clean Up Noise & Fix the 3 Failures

**Goal:** All existing tests pass. No files that add zero coverage.

### 0a. Delete noise files

These add no test coverage and should be removed:

| File | Why |
|---|---|
| `CompilationTest.swift` | Tests that types exist — the compiler already guarantees this |
| `add_test_target.py` | One-time setup script |
| `configure_tests.sh`, `setup_tests.sh` | One-time setup scripts |
| `ADD_TESTS_TO_PROJECT.md`, `TEST_SUITE_SUMMARY.md`, `TEST_RESULTS.md`, `QUICK_REFERENCE.md`, `TimeControlTests/README.md` | Scaffolding docs, not product docs |

### 0b. Fix `testSubtaskEqualityWithDifferentContent`

The test asserts `XCTAssertEqual(subtask1, subtask2)` for two `Subtask` instances that share an `id` but have different `title` and `isCompleted`. Confirm the `Equatable` conformance on `Subtask` is based on `id` only. If it is, the test should pass once you confirm that by reading the model. If `Equatable` compares all fields, the test is wrong and the assertion should be changed — equality by `id` is the correct semantic for value types with a stable identity.

Run before fixing:

```bash
xcodebuild test -scheme TimeControl -destination 'platform=macOS' \
  -only-testing TimeControlTests/SubtaskTests/testSubtaskEqualityWithDifferentContent
```

Confirm the failure message, then fix.

### 0c. Fix `TodoStorageTests` URL isolation

**Root cause:** All 15 storage tests call `TodoStorage.save(todos:notificationRecords:)` and `TodoStorage.load()` without any URL parameter. Every call goes to `~/Documents/todos.json`. This means:

- Tests pollute the real app data
- `testLoadWhenFileDoesNotExist` fails because the real file exists

**Fix — add URL parameter with a default to `TodoStorage`:**

```swift
// TodoStorage.swift
static func save(todos: [TodoItem], notificationRecords: [NotificationRecord], to url: URL = storageURL)
static func load(from url: URL = storageURL) -> (todos: [TodoItem], notificationRecords: [NotificationRecord])
```

Make `storageURL` `internal` (not `private`) so `TestHelpers` can reference it if needed.

**Update every call in `TodoStorageTests`** to pass `testStorageURL`:

```swift
TodoStorage.save(todos: todos, notificationRecords: [], to: testStorageURL)
let result = TodoStorage.load(from: testStorageURL)
```

**TDD order:**
1. Run `testLoadWhenFileDoesNotExist` — confirm it fails because it finds real data
2. Add `from:` parameter to `load()` — test still fails (URL not yet passed)
3. Update test to pass `testStorageURL` — test passes

**Exit criteria:** 0 test failures. 0 tests touching real `~/Documents/todos.json`.

---

## Phase 1 — Infrastructure: TestHelpers + ViewModel Initializer

**Goal:** Shared factories and an injectable `TodoViewModel` in place before writing any ViewModel tests. No new test coverage yet — just the scaffolding that all later phases depend on.

### 1a. Add a test-friendly initializer to `TodoViewModel`

`TodoViewModel.init()` currently calls `TodoStorage.load()` against the real file. Tests need to inject a temp URL.

```swift
// TodoViewModel.swift
init(storageURL: URL = TodoStorage.storageURL) {
    self.storageURL = storageURL
    let loaded = TodoStorage.load(from: storageURL)
    self.todos = loaded.todos
    // ... rest of init unchanged
}
```

**TDD order:** Write a test that calls `TodoViewModel(storageURL: url)` first. It will fail to compile. That compile failure is the red signal — add the initializer to go green.

### 1b. Create `TestHelpers.swift`

```
TimeControlTests/Helpers/TestHelpers.swift
```

```swift
import Foundation
@testable import TimeControl

func makeTodo(
    text: String = "Test task",
    isCompleted: Bool = false,
    estimatedTime: TimeInterval = 0,
    subtasks: [Subtask] = []
) -> TodoItem {
    TodoItem(text: text, isCompleted: isCompleted, estimatedTime: estimatedTime, subtasks: subtasks)
}

func makeSubtask(title: String = "Subtask", isCompleted: Bool = false) -> Subtask {
    Subtask(title: title, isCompleted: isCompleted)
}

func makeViewModel() -> (vm: TodoViewModel, url: URL) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".json")
    let vm = TodoViewModel(storageURL: url)
    return (vm, url)
}
```

**Exit criteria:** `makeViewModel()` compiles. `TodoViewModel(storageURL: url)` starts with empty todos regardless of whether `~/Documents/todos.json` exists.

---

## Phase 2 — ViewModel Tests (Highest Priority)

**Goal:** The critical business logic in `TodoViewModel` is covered. These are the tests that catch regressions in timer enforcement, subtask auto-start, and task switching.

Create: `TimeControlTests/ViewModel/TodoViewModelTests.swift`

For every test below: write it → run it → confirm assertion failure (not a crash) → write production code.

### Task lifecycle

```swift
func testAddTodo_appendsToTodos() {
    let (vm, _) = makeViewModel()
    vm.newTodoText = "Write report"
    vm.addTodo()
    XCTAssertEqual(vm.todos.count, 1)
    XCTAssertEqual(vm.todos[0].text, "Write report")
    XCTAssertTrue(vm.newTodoText.isEmpty)
}

func testAddTodo_emptyText_doesNotAdd() {
    let (vm, _) = makeViewModel()
    vm.newTodoText = "   "
    vm.addTodo()
    XCTAssertTrue(vm.todos.isEmpty)
}

func testToggleTodo_completesTask_andStopsTimer() {
    let (vm, _) = makeViewModel()
    vm.newTodoText = "Task"
    vm.addTodo()
    vm.toggleTimer(vm.todos[0])
    vm.toggleTodo(vm.todos[0])
    XCTAssertTrue(vm.todos[0].isCompleted)
    XCTAssertFalse(vm.todos[0].isRunning)
    XCTAssertNotNil(vm.todos[0].completedAt)
}

func testDeleteTodo_removesFromList() {
    XCTFail("not implemented yet")
}
```

### Timer — single task enforcement (critical business rule)

```swift
func testToggleTimer_onlyOneTaskRunsAtATime() {
    let (vm, _) = makeViewModel()
    vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]

    vm.toggleTimer(vm.todos[0])
    XCTAssertTrue(vm.todos[0].isRunning)
    XCTAssertFalse(vm.todos[1].isRunning)

    vm.toggleTimer(vm.todos[1])
    XCTAssertFalse(vm.todos[0].isRunning) // stopped
    XCTAssertTrue(vm.todos[1].isRunning)  // started
}

func testToggleTimer_pause_stopsTimer() {
    let (vm, _) = makeViewModel()
    vm.todos = [makeTodo(text: "A")]
    vm.toggleTimer(vm.todos[0])
    vm.toggleTimer(vm.todos[0]) // pause
    XCTAssertFalse(vm.todos[0].isRunning)
    XCTAssertNil(vm.runningTaskId)
}

func testToggleTimer_setsStartedAt_onFirstStart() {
    let (vm, _) = makeViewModel()
    vm.todos = [makeTodo(text: "A")]
    XCTAssertNil(vm.todos[0].startedAt)
    vm.toggleTimer(vm.todos[0])
    XCTAssertNotNil(vm.todos[0].startedAt)
}

func testToggleTimer_doesNotOverwriteStartedAt_onResume() {
    let (vm, _) = makeViewModel()
    vm.todos = [makeTodo(text: "A")]
    vm.toggleTimer(vm.todos[0])
    let firstStart = vm.todos[0].startedAt
    vm.toggleTimer(vm.todos[0]) // pause
    vm.toggleTimer(vm.todos[0]) // resume
    XCTAssertEqual(vm.todos[0].startedAt, firstStart)
}
```

### Subtask auto-start (critical business rule)

```swift
func testToggleSubtask_completing_autoStartsNextIncomplete() {
    let (vm, _) = makeViewModel()
    let sub1 = makeSubtask(title: "First")
    let sub2 = makeSubtask(title: "Second")
    vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

    vm.toggleTimer(vm.todos[0])
    vm.toggleSubtaskTimer(vm.todos[0].subtasks[0], in: vm.todos[0])
    vm.toggleSubtask(vm.todos[0].subtasks[0], in: vm.todos[0])

    XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.title == "Second" })!.isRunning)
}

func testToggleSubtask_completing_pausesItsTimer() {
    let (vm, _) = makeViewModel()
    let sub = makeSubtask(title: "Sub")
    vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

    vm.toggleTimer(vm.todos[0])
    vm.toggleSubtaskTimer(vm.todos[0].subtasks[0], in: vm.todos[0])
    XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

    vm.toggleSubtask(vm.todos[0].subtasks[0], in: vm.todos[0])
    XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
}

func testToggleSubtaskTimer_requiresParentRunning() {
    let (vm, _) = makeViewModel()
    let sub = makeSubtask(title: "Sub")
    vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
    // parent NOT started
    vm.toggleSubtaskTimer(vm.todos[0].subtasks[0], in: vm.todos[0])
    XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
}

func testToggleSubtaskTimer_onlyOneSubtaskRunsAtATime() {
    let (vm, _) = makeViewModel()
    let sub1 = makeSubtask(title: "A")
    let sub2 = makeSubtask(title: "B")
    vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

    vm.toggleTimer(vm.todos[0])
    vm.toggleSubtaskTimer(vm.todos[0].subtasks[0], in: vm.todos[0])
    vm.toggleSubtaskTimer(vm.todos[0].subtasks[1], in: vm.todos[0])

    XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    XCTAssertTrue(vm.todos[0].subtasks[1].isRunning)
}
```

### Subtask ordering (critical business rule)

```swift
func testCompletedSubtasks_movedToTopOfCompletedBlock() {
    XCTFail("not implemented yet")
}

func testStartedSubtasks_movedToTopOfIncompleteList() {
    XCTFail("not implemented yet")
}
```

### switchToTask

```swift
func testSwitchToTask_stopsCurrentTask() {
    let (vm, _) = makeViewModel()
    vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
    vm.toggleTimer(vm.todos[0])
    vm.switchToTask(vm.todos[1])
    XCTAssertFalse(vm.todos[0].isRunning)
}

func testSwitchToTask_autoPlays_whenSettingEnabled() {
    let (vm, _) = makeViewModel()
    vm.autoPlayAfterSwitching = true
    vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
    vm.toggleTimer(vm.todos[0])
    vm.switchToTask(vm.todos[1])
    XCTAssertTrue(vm.todos[1].isRunning)
}

func testSwitchToTask_doesNotAutoPlay_whenSettingDisabled() {
    let (vm, _) = makeViewModel()
    vm.autoPlayAfterSwitching = false
    vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
    vm.toggleTimer(vm.todos[0])
    vm.switchToTask(vm.todos[1])
    XCTAssertFalse(vm.todos[1].isRunning)
}
```

### Persistence round-trip

```swift
func testSaveTodos_persistsAndLoadsCorrectly() {
    let (vm, url) = makeViewModel()
    vm.newTodoText = "Persisted task"
    vm.addTodo()
    vm.saveTodos()

    let vm2 = TodoViewModel(storageURL: url)
    XCTAssertEqual(vm2.todos.count, 1)
    XCTAssertEqual(vm2.todos[0].text, "Persisted task")
}
```

### Field updates

```swift
func testUpdateTaskFields_updatesTitleAndNotes() {
    let (vm, _) = makeViewModel()
    vm.todos = [makeTodo(text: "Old")]
    let id = vm.todos[0].id
    vm.updateTaskFields(id: id, text: "New", description: nil, notes: "my note",
                        dueDate: nil, isAdhoc: nil, fromWho: nil, estimatedTime: nil)
    XCTAssertEqual(vm.todos[0].text, "New")
    XCTAssertEqual(vm.todos[0].notes, "my note")
}
```

### Stubs (implement in a later pass)

```swift
func testSetCountdown_storesCountdownTime() { XCTFail("not implemented yet") }
func testClearCountdown_removesCountdownTime() { XCTFail("not implemented yet") }
func testMoveTodo_updatesIndexOrder() { XCTFail("not implemented yet") }
```

**Exit criteria:** All non-stub ViewModel tests green. `~/Documents/todos.json` is never touched by any test.

---

## Phase 3 — Filter & Sort Tests

Create: `TimeControlTests/ViewModel/FilterSortTests.swift`

These test the computed properties / filter logic on `TodoViewModel` (e.g. `incompleteTodos`, `completedTodos`, `filterText` matching).

```swift
func testFilterText_matchesTitle() { XCTFail("not implemented yet") }
func testFilterText_matchesSubtaskTitle() { XCTFail("not implemented yet") }
func testFilterText_matchesFromWho() { XCTFail("not implemented yet") }
func testFilterText_emptyQuery_returnsAll() { XCTFail("not implemented yet") }
func testSortOption_recentlyPlayed_orderedByLastPlayedAt() { XCTFail("not implemented yet") }
func testSortOption_dueDate_nearestFirst() { XCTFail("not implemented yet") }
func testSortOption_creationDate_newestFirst() { XCTFail("not implemented yet") }
func testIncompleteTodos_excludesCompleted() { XCTFail("not implemented yet") }
func testCompletedTodos_excludesIncomplete() { XCTFail("not implemented yet") }
```

Each stub must be replaced with a real assertion before this phase is considered done. Follow red-green-refactor for each.

---

## Phase 4 — Model Extensions

### TaskSessionTests.swift (new)

Create: `TimeControlTests/Models/TaskSessionTests.swift`

```swift
final class TaskSessionTests: XCTestCase {

    func testSession_stoppedAt_nil_whenOngoing() {
        let s = TaskSession(startedAt: 1000)
        XCTAssertNil(s.stoppedAt)
    }

    func testSession_duration_whenStopped() {
        let s = TaskSession(startedAt: 1000, stoppedAt: 1060)
        XCTAssertEqual(s.stoppedAt! - s.startedAt, 60)
    }
}
```

### Extend TodoItemTests.swift

Add to the existing file:

```swift
func testCurrentTimeSpent_accumulates_acrossSessions() {
    var item = makeTodo()
    item.totalTimeSpent = 120
    item.lastStartTime = Date().addingTimeInterval(-30)
    XCTAssertGreaterThanOrEqual(item.currentTimeSpent, 150, accuracy: 1.0)
}

func testCountdownElapsed_clampedToCountdownTime() {
    var item = makeTodo()
    item.countdownTime = 300
    item.countdownElapsedAtPause = 350 // exceeds countdown
    XCTAssertEqual(item.countdownElapsed, 300) // clamped
}

func testCountdownElapsed_zero_whenNoCountdownSet() {
    let item = makeTodo()
    XCTAssertEqual(item.countdownElapsed, 0)
}
```

---

## Phase 5 — NotificationScheduler Tests

Create: `TimeControlTests/Services/NotificationSchedulerTests.swift`

Avoid touching `UNUserNotificationCenter` — test only scheduling state and `snap` logic.

Note: `snap` is currently `private`. Change it to `internal` so `@testable import` can reach it, or test it indirectly by observing the snapped date stored in `pending`.

```swift
final class NotificationSchedulerTests: XCTestCase {

    func testSnap_zerosSeconds() {
        let scheduler = NotificationScheduler.shared
        let date = Date()
        let snapped = scheduler.snap(date)
        XCTAssertEqual(Calendar.current.component(.second, from: snapped), 0)
    }

    func testSchedule_addsToPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(3600)
        scheduler.schedule(task)
        XCTAssertNotNil(scheduler.pending[task.id])
        scheduler.cancel(for: task.id) // cleanup
    }

    func testCancel_removesFromPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(3600)
        scheduler.schedule(task)
        scheduler.cancel(for: task.id)
        XCTAssertNil(scheduler.pending[task.id])
    }

    func testSchedule_pastDate_doesNotAddToPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(-3600)
        scheduler.schedule(task)
        XCTAssertNil(scheduler.pending[task.id])
    }
}
```

---

## Recommended File Structure (target state)

```
TimeControlTests/
  Helpers/
    TestHelpers.swift           ← Phase 1
  Models/
    TodoItemTests.swift         ← Phase 0 + 4 (extend)
    SubtaskTests.swift          ← Phase 0 (fix equality)
    TaskSessionTests.swift      ← Phase 4 (new)
  ViewModel/
    TodoViewModelTests.swift    ← Phase 2 (new, most important)
    FilterSortTests.swift       ← Phase 3 (new)
  Services/
    TimeFormattingTests.swift   ← already passing
    TodoStorageTests.swift      ← Phase 0 (fix URL isolation)
    NotificationSchedulerTests.swift ← Phase 5 (new)
```

Views and window management are excluded — they require AppKit/SwiftUI infrastructure and are not practical to unit test.

---

## Running Tests

```bash
# All tests
xcodebuild test -scheme TimeControl -destination 'platform=macOS'

# One class
xcodebuild test -scheme TimeControl -destination 'platform=macOS' \
  -only-testing TimeControlTests/TodoViewModelTests

# One method
xcodebuild test -scheme TimeControl -destination 'platform=macOS' \
  -only-testing TimeControlTests/TodoViewModelTests/testToggleTimer_onlyOneTaskRunsAtATime
```

In Xcode: `Cmd+U` runs all tests. Click the diamond gutter icon to run a single test.

---

## Coverage Checklist

| Phase | Area | File | Status |
|---|---|---|---|
| 0 | Clean up noise | `CompilationTest.swift` + scripts + stale docs | Delete |
| 0 | Subtask equality | `SubtaskTests.swift` | Fix 1 test |
| 0 | Storage isolation | `TodoStorage.swift` + `TodoStorageTests.swift` | Add URL param, update tests |
| 1 | ViewModel init | `TodoViewModel.swift` | Add `storageURL` param |
| 1 | Test helpers | `TestHelpers.swift` | Create |
| 2 | Task CRUD | `TodoViewModelTests.swift` | Create |
| 2 | Timer enforcement | `TodoViewModelTests.swift` | Create |
| 2 | Subtask auto-start | `TodoViewModelTests.swift` | Create |
| 2 | Subtask ordering | `TodoViewModelTests.swift` | Stubs → implement |
| 2 | switchToTask | `TodoViewModelTests.swift` | Create |
| 2 | Field updates | `TodoViewModelTests.swift` | Create |
| 2 | Countdown | `TodoViewModelTests.swift` | Stubs → implement |
| 2 | Persistence round-trip | `TodoViewModelTests.swift` | Create |
| 3 | Filter & sort | `FilterSortTests.swift` | Create |
| 4 | TaskSession model | `TaskSessionTests.swift` | Create |
| 4 | TodoItem computed props | `TodoItemTests.swift` | Extend |
| 5 | NotificationScheduler | `NotificationSchedulerTests.swift` | Create |
| — | Views / WindowManagement | — | Skip (AppKit) |
