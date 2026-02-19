# ContentView.swift Refactoring Plan

## Current State

`ContentView.swift` is **4,400 lines** containing 6 separate structs and duplicated business logic.
The previous refactoring (Phases 1-4) extracted models, services, small views, and window managers,
but left the largest and most complex pieces behind.

### What remains in ContentView.swift

| Struct | Lines | Size |
|---|---|---|
| `ContentView` (state + body + business logic + 15 NotificationCenter handlers) | 13-1639 | ~1,627 lines |
| `TodoRow` | 1641-2219 | ~579 lines |
| `EditTodoSheet` | 2221-2410 | ~190 lines |
| `FloatingEditView` | 2412-2647 | ~236 lines |
| `MassOperationsSheet` | 2649-3022 | ~374 lines |
| `FloatingTaskWindowView` | 3024-4395 | ~1,372 lines |

### Key architectural problem

`ContentView` owns all state and business logic. `FloatingTaskWindowView` (the floating window)
communicates back to `ContentView` via **15 NotificationCenter posts**, each requiring a matching
`.onReceive` handler in ContentView. This is ~400 lines of boilerplate notification plumbing.

A `TodoViewModel.swift` (561 lines) already exists with the correct business logic methods, but
**ContentView does not use it** -- it still has its own duplicate copies of every method.

---

## Refactoring Phases

### Phase A: Extract the 5 remaining view structs into their own files

Move each struct out of `ContentView.swift` into `Views/`. These are pure cut-and-paste
extractions with no logic changes.

#### A1. Extract `TodoRow` -> `Views/TodoRow.swift`

- **Cut** lines 1641-2219 from `ContentView.swift`
- **Create** `Views/TodoRow.swift` with imports: `SwiftUI`, `AppKit`
- The struct is self-contained: it receives all data via init parameters and closures
- It references `TimeFormatter` (already extracted) and `ExportWindowManager` (already extracted)
- No changes needed to the struct itself

#### A2. Extract `EditTodoSheet` -> `Views/EditTodoSheet.swift`

- **Cut** lines 2221-2410 from `ContentView.swift`
- **Create** `Views/EditTodoSheet.swift` with imports: `SwiftUI`
- Self-contained: takes a `Binding<TodoItem>` and an `onSave` closure
- Has its own `formatTimestamp` helper that can stay as-is

#### A3. Extract `FloatingEditView` -> `Views/FloatingEditView.swift`

- **Cut** lines 2412-2647 from `ContentView.swift`
- **Create** `Views/FloatingEditView.swift` with imports: `SwiftUI`
- Self-contained: takes a `TodoItem`, `onSave`, and `onCancel` closures
- Has its own `formatTimestamp` helper (duplicate of EditTodoSheet's -- note for future DRY cleanup)

#### A4. Extract `MassOperationsSheet` -> `Views/MassOperationsSheet.swift`

- **Cut** lines 2649-3022 from `ContentView.swift`
- **Create** `Views/MassOperationsSheet.swift` with imports: `SwiftUI`
- Takes `Binding<[TodoItem]>` and an `onSave` closure
- References `MassOperationType` and `EditableField` enums (already in `Models/Enums.swift`)

#### A5. Extract `FloatingTaskWindowView` -> `Views/FloatingTaskWindowView.swift`

- **Cut** lines 3024-4395 from `ContentView.swift`
- **Create** `Views/FloatingTaskWindowView.swift` with imports: `SwiftUI`, `AppKit`, `AVFoundation`
- References `FloatingWindowManager`, `FloatingEditView`, `NotesEditorView`, `ReminderAlertView`,
  `TimerPickerSheet`, `NewTaskPopupView`, `PauseTaskConfirmationView`, `TimeFormatter`,
  `ExportWindowManager` -- all already extracted
- This is the most complex view (~1,372 lines) but structurally self-contained

#### Result after Phase A

`ContentView.swift` drops from **4,400 lines to ~1,640 lines**. It will contain only the
`ContentView` struct itself (state, body, business logic, notification handlers).

---

### Phase B: Wire up `TodoViewModel` and remove duplicate logic from ContentView

The existing `ViewModels/TodoViewModel.swift` already contains correct implementations of all
business logic methods. This phase connects it.

#### B1. Change ContentView to use TodoViewModel

Replace all `@State` properties that the ViewModel already manages:

```swift
// BEFORE (ContentView.swift lines 14-30)
@State private var todos: [TodoItem] = []
@State private var newTodoText: String = ""
@State private var filterText: String = ""
@State private var timerUpdateTrigger = 0
@State private var editingTodo: TodoItem?
@State private var expandedTodos: Set<UUID> = []
@State private var newSubtaskTexts: [UUID: String] = [:]
@State private var isCompletedSectionExpanded: Bool = false
@State private var runningTaskId: UUID?
@State private var isAdvancedMode: Bool = false
@State private var areAllTasksExpanded: Bool = false
@State private var sortOption: TaskSortOption = .creationDateNewest
@State private var showingMassOperations: Bool = false
@State private var showingSettings: Bool = false
@State private var todoToDelete: TodoItem?
@State private var subtaskToDelete: (subtask: Subtask, parentTodo: TodoItem)?

// AFTER
@StateObject private var viewModel = TodoViewModel()
```

Properties that **must stay in ContentView** (they are view-specific):

- `@FocusState private var subtaskInputFocused: UUID?` (SwiftUI focus state cannot live in a ViewModel)
- `@AppStorage(...)` properties (6 total) -- these read/write UserDefaults and should sync to ViewModel

#### B2. Sync @AppStorage settings to ViewModel

Add an `.onAppear` and `.onChange` bridge so the ViewModel's settings match UserDefaults:

```swift
.onAppear {
    viewModel.activateReminders = activateReminders
    viewModel.confirmTaskDeletion = confirmTaskDeletion
    viewModel.confirmSubtaskDeletion = confirmSubtaskDeletion
    viewModel.showTimeWhenCollapsed = showTimeWhenCollapsed
    viewModel.autoPlayAfterSwitching = autoPlayAfterSwitching
    viewModel.autoPauseAfterMinutes = autoPauseAfterMinutes
}
.onChange(of: activateReminders) { viewModel.activateReminders = $0 }
.onChange(of: confirmTaskDeletion) { viewModel.confirmTaskDeletion = $0 }
// ... etc for each @AppStorage property
```

#### B3. Update body references

Every reference to a local property or method in the body changes to go through `viewModel`:

- `todos` -> `viewModel.todos`
- `incompleteTodos` -> `viewModel.incompleteTodos`
- `completedTodos` -> `viewModel.completedTodos`
- `addTodo()` -> `viewModel.addTodo()`
- `toggleTodo(todo)` -> `viewModel.toggleTodo(todo)`
- `toggleTimer(todo)` -> `viewModel.toggleTimer(todo)`
- `saveTodos()` -> `viewModel.saveTodos()`
- etc.

Two-way bindings change from `$newTodoText` to `$viewModel.newTodoText`, etc.

#### B4. Delete duplicate business logic methods from ContentView

Remove all `private func` methods from ContentView that are now in the ViewModel (lines 1054-1639):

- `addTodo()`, `toggleTodo(_:)`, `deleteTodo(_:)`, `performDeleteTodo(_:)`, `saveTodos()`
- `editTodo(_:)`, `switchToTask(_:)`, `toggleTimer(_:)`, `toggleSubtaskTimer(_:in:)`
- `moveTodo(from:to:)`, `addSubtask(to:)`, `toggleExpanded(_:)`, `toggleExpandAll()`
- `toggleSubtask(_:in:)`, `deleteSubtask(_:from:)`, `performDeleteSubtask(_:from:)`
- `generateExportTextForTask(_:)`, `generateExportTextForAllTasks()`
- `editSubtask(_:in:)`, `sortTodos(_:)`, `filterTodos(_:)`

Also remove the duplicate computed properties `incompleteTodos` and `completedTodos`.

This removes **~585 lines** from ContentView.

#### B5. Remove `init()` from ContentView

The ViewModel handles loading from storage in its own `init()`. The ContentView `init()` (lines 42-45)
becomes unnecessary.

#### B6. Handle the timer

ContentView currently creates its own `Timer.publish(every: 1, ...)`. The ViewModel already starts
its own timer internally. Remove the ContentView timer and the `.onReceive(timer)` handler
(lines 612-619). The ViewModel's `timerUpdateTrigger` will drive UI updates.

#### Result after Phase B

`ContentView.swift` drops from ~1,640 to **~1,050 lines**. It still has ~400 lines of
NotificationCenter handlers that we address next.

---

### Phase C: Eliminate NotificationCenter handlers

Currently `FloatingTaskWindowView` posts notifications, and ContentView receives them with
`.onReceive(...)`. With the ViewModel shared, this indirection is unnecessary.

#### C1. Share the ViewModel with FloatingTaskWindowView

Update `FloatingWindowManager.showFloatingWindow(...)` to accept and pass through the ViewModel:

```swift
// FloatingWindowManager.swift
func showFloatingWindow(for task: TodoItem, viewModel: TodoViewModel) {
    // ...
    let contentView = FloatingTaskWindowView(task: task, windowManager: self, viewModel: viewModel)
    // ...
}
```

Update `ContentView` to pass the ViewModel:

```swift
FloatingWindowManager.shared.showFloatingWindow(for: todos[index], viewModel: viewModel)
```

#### C2. Update FloatingTaskWindowView to call ViewModel directly

Replace every `NotificationCenter.default.post(...)` in `FloatingTaskWindowView` with a direct
ViewModel method call. The 15 notification types and their replacements:

| Notification Name | ViewModel Method |
|---|---|
| `ToggleSubtaskFromFloatingWindow` | `viewModel.toggleSubtask(_:in:)` |
| `AddSubtaskFromFloatingWindow` | `viewModel.addSubtask(to:)` (or custom variant) |
| `DeleteSubtaskFromFloatingWindow` | `viewModel.performDeleteSubtask(_:from:)` |
| `ToggleSubtaskTimerFromFloatingWindow` | `viewModel.toggleSubtaskTimer(_:in:)` |
| `UpdateNotesFromFloatingWindow` | Direct property update on ViewModel |
| `CompleteTaskFromFloatingWindow` | `viewModel.toggleTodo(_:)` |
| `PauseTaskFromFloatingWindow` | New `viewModel.pauseTask(_:keepWindowOpen:)` method |
| `ResumeTaskFromFloatingWindow` | New `viewModel.resumeTask(_:)` method |
| `EditTaskFromFloatingWindow` | `viewModel.editTodo(_:)` |
| `UpdateTaskFromFloatingWindow` | New `viewModel.updateTask(id:...)` method |
| `SetCountdownFromFloatingWindow` | New `viewModel.setCountdown(taskId:time:)` method |
| `ClearCountdownFromFloatingWindow` | New `viewModel.clearCountdown(taskId:)` method |
| `CreateTaskFromFloatingWindow` | New `viewModel.createAndSwitchToTask(title:switch:)` method |
| `SwitchTaskFromFloatingWindow` | `viewModel.switchToTask(_:)` |
| `CloseFloatingWindow` (via delegate) | Already handled by `FloatingWindowManager` |

#### C3. Add missing ViewModel methods

Some notification handlers contain logic not yet in the ViewModel. Add these methods:

- `pauseTask(_ taskId: UUID, keepWindowOpen: Bool)` -- extracted from the `PauseTaskFromFloatingWindow` handler
- `resumeTask(_ taskId: UUID)` -- extracted from `ResumeTaskFromFloatingWindow` handler
- `updateTaskFields(id: UUID, text: String?, description: String?, notes: String?, ...)` -- extracted from `UpdateTaskFromFloatingWindow` handler
- `setCountdown(taskId: UUID, time: TimeInterval)` -- extracted from `SetCountdownFromFloatingWindow`
- `clearCountdown(taskId: UUID)` -- extracted from `ClearCountdownFromFloatingWindow`
- `createTask(title: String, switchToIt: Bool)` -- extracted from `CreateTaskFromFloatingWindow`

#### C4. Remove all `.onReceive(NotificationCenter...)` handlers from ContentView

Delete all 15 `.onReceive(...)` blocks (lines 621-999), which total **~380 lines**.

#### C5. Clean up FloatingWindowManager

Simplify `showFloatingWindow(...)` signature -- it no longer needs to pass individual settings
booleans since the ViewModel carries them. Remove stored settings properties from the manager:

```swift
// Remove these from FloatingWindowManager:
var activateReminders: Bool = false
var showTimeWhenCollapsed: Bool = false
var autoPlayAfterSwitching: Bool = false
var autoPauseAfterMinutes: Int = 0
```

#### Result after Phase C

`ContentView.swift` drops from ~1,050 to **~670 lines**. The notification handlers are gone,
replaced by ~100 lines of new ViewModel methods in `TodoViewModel.swift`.

---

### Phase D: Clean up ContentView body (extract sub-views)

The remaining ~670 lines of ContentView is mostly the `body` property with the toolbar,
incomplete list, completed section, sheets, and dialogs. Extract inline sub-views to make it
more readable.

#### D1. Extract `TaskListToolbar` sub-view

Lines 160-280 (add todo field, filter, advanced mode toggle, sort picker) -> private sub-view or
separate file.

#### D2. Extract `TaskListItem` sub-view

The repeated pattern of `TodoRow` + expanded subtask area + drag/drop handling (appears twice:
once for incomplete and once for completed) -> shared private sub-view.

#### D3. Extract `CompletedTasksSection` sub-view

Lines 444-607 (the collapsible completed section) -> private sub-view.

#### Result after Phase D

`ContentView.swift` reaches approximately **~250-350 lines**: a clean view struct that composes
sub-views, binds the ViewModel, manages @AppStorage syncing, and presents sheets/dialogs.

---

## Execution Order and Dependencies

```
Phase A (extract 5 view files)
    |
    v
Phase B (wire up TodoViewModel)
    |
    v
Phase C (eliminate NotificationCenter)
    |
    v
Phase D (extract ContentView sub-views)
```

Each phase is independently buildable and testable. The app should compile and function
correctly after each phase.

## Expected Final Line Counts

| File | Lines |
|---|---|
| `ContentView.swift` | ~300 |
| `TodoViewModel.swift` | ~700 (existing 561 + ~140 new methods from Phase C) |
| `Views/TodoRow.swift` | ~579 |
| `Views/EditTodoSheet.swift` | ~190 |
| `Views/FloatingEditView.swift` | ~236 |
| `Views/MassOperationsSheet.swift` | ~374 |
| `Views/FloatingTaskWindowView.swift` | ~1,250 (1,372 minus ~120 lines of notification posts replaced with ViewModel calls) |
| `Views/TaskListToolbar.swift` (new) | ~120 |
| `Views/TaskListItem.swift` (new) | ~100 |
| `Views/CompletedTasksSection.swift` (new) | ~80 |

## Risks and Notes

1. **Phase A is safe** -- pure file moves with no logic changes. If the project builds before,
   it builds after. Test by building in Xcode after each file extraction.

2. **Phase B changes data flow** -- switching from `@State` to `@StateObject` changes ownership
   semantics. The ViewModel persists across view reloads (good), but bindings change syntax.
   Test all UI interactions after this phase.

3. **Phase C is the highest-risk phase** -- it changes the communication model between ContentView
   and FloatingTaskWindowView. Test every floating window action: play/pause, switch tasks,
   add/toggle/delete subtasks, edit task, set countdown, create new task, complete task, reminder
   handling.

4. **@AppStorage must stay in ContentView** -- `@AppStorage` is a property wrapper that only works
   in SwiftUI views. The ViewModel gets synced copies. An alternative is to read UserDefaults
   directly in the ViewModel, but the current approach keeps the single source of truth in SwiftUI.

5. **FloatingEditView and EditTodoSheet share near-identical code** -- consider merging them into
   a single view with a mode flag in a future cleanup pass. Not in scope for this plan.

6. **The `subtaskToDelete` tuple** -- `TodoViewModel` stores `(subtask: Subtask, parentTodo: TodoItem)`
   as a `@Published` property. Tuples don't conform to `Equatable` by default in this context,
   so the confirmation dialog binding may need a small wrapper struct. Watch for compiler errors here.

7. **Xcode project file** -- every new `.swift` file must be added to the Xcode project's build
   sources. Drag the `Views/` folder into the project navigator after creating new files, or add
   them individually.
