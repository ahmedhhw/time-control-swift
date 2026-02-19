# Phase C Refactoring - Complete

## Summary

Phase C has been successfully completed. This phase eliminated all NotificationCenter handlers between `FloatingTaskWindowView` and `ContentView` by sharing the `TodoViewModel` between them.

## Changes Made

### 1. TodoViewModel.swift - Added New Methods

Added the following methods to handle operations previously done via NotificationCenter:

- `pauseTask(_ taskId: UUID, keepWindowOpen: Bool)` - Pauses a task with optional window keep-open
- `resumeTask(_ taskId: UUID)` - Resumes a paused task
- `updateTaskFields(id:text:description:notes:dueDate:isAdhoc:fromWho:estimatedTime:)` - Updates task fields
- `setCountdown(taskId:time:)` - Sets countdown timer for a task
- `clearCountdown(taskId:)` - Clears countdown timer
- `createTask(title:switchToIt:)` - Creates a new task and optionally switches to it
- `toggleSubtaskFromFloatingWindow(_:in:)` - Toggles subtask completion from floating window
- `addSubtaskFromFloatingWindow(to:title:)` - Adds a subtask from floating window
- `deleteSubtaskFromFloatingWindow(_:from:)` - Deletes a subtask from floating window
- `toggleSubtaskTimerFromFloatingWindow(_:in:)` - Toggles subtask timer from floating window
- `updateNotesFromFloatingWindow(_:for:)` - Updates task notes from floating window
- `completeTaskFromFloatingWindow(_:)` - Marks a task as complete from floating window

### 2. FloatingWindowManager.swift - Updated to Pass ViewModel

**Before:**
```swift
func showFloatingWindow(for task: TodoItem, allTodos: [TodoItem], 
                       activateReminders: Bool, showTimeWhenCollapsed: Bool, 
                       autoPlayAfterSwitching: Bool, autoPauseAfterMinutes: Int, 
                       onTaskSwitch: @escaping (TodoItem) -> Void)
```

**After:**
```swift
func showFloatingWindow(for task: TodoItem, viewModel: TodoViewModel)
```

- Removed individual settings parameters (activateReminders, showTimeWhenCollapsed, etc.)
- Added `weak var viewModel: TodoViewModel?` to store reference
- Simplified initialization by passing ViewModel directly to FloatingTaskWindowView

### 3. FloatingTaskWindowView.swift - Updated to Use ViewModel

**Changes:**
- Removed individual setting properties (activateReminders, showTimeWhenCollapsed, etc.)
- Added `@ObservedObject var viewModel: TodoViewModel`
- Updated init signature to accept viewModel parameter
- Replaced all `NotificationCenter.default.post(...)` calls with direct ViewModel method calls:
  - `NotificationCenter...("ToggleSubtaskFromFloatingWindow")` → `viewModel.toggleSubtaskFromFloatingWindow()`
  - `NotificationCenter...("AddSubtaskFromFloatingWindow")` → `viewModel.addSubtaskFromFloatingWindow()`
  - `NotificationCenter...("DeleteSubtaskFromFloatingWindow")` → `viewModel.deleteSubtaskFromFloatingWindow()`
  - `NotificationCenter...("ToggleSubtaskTimerFromFloatingWindow")` → `viewModel.toggleSubtaskTimerFromFloatingWindow()`
  - `NotificationCenter...("CompleteTaskFromFloatingWindow")` → `viewModel.completeTaskFromFloatingWindow()`
  - `NotificationCenter...("PauseTaskFromFloatingWindow")` → `viewModel.pauseTask()`
  - `NotificationCenter...("ResumeTaskFromFloatingWindow")` → `viewModel.resumeTask()`
  - `NotificationCenter...("UpdateTaskFromFloatingWindow")` → `viewModel.updateTaskFields()`
  - `NotificationCenter...("SetCountdownFromFloatingWindow")` → `viewModel.setCountdown()`
  - `NotificationCenter...("ClearCountdownFromFloatingWindow")` → `viewModel.clearCountdown()`
  - `NotificationCenter...("CreateTaskFromFloatingWindow")` → `viewModel.createTask()`

- Changed all references to settings properties to use viewModel:
  - `activateReminders` → `viewModel.activateReminders`
  - `showTimeWhenCollapsed` → `viewModel.showTimeWhenCollapsed`
  - `autoPlayAfterSwitching` → `viewModel.autoPlayAfterSwitching`
  - `autoPauseAfterMinutes` → `viewModel.autoPauseAfterMinutes`

### 4. NotesEditorView.swift - Updated to Use ViewModel

- Added `@ObservedObject var viewModel: TodoViewModel` parameter
- Changed `NotificationCenter.default.post(...)` to `viewModel.updateNotesFromFloatingWindow()`
- Updated init to accept viewModel parameter
- Updated call site in FloatingTaskWindowView to pass viewModel

### 5. ContentView.swift - Removed All NotificationCenter Handlers

**Removed 15 `.onReceive()` handlers (~378 lines):**
1. ToggleSubtaskFromFloatingWindow
2. AddSubtaskFromFloatingWindow
3. DeleteSubtaskFromFloatingWindow
4. ToggleSubtaskTimerFromFloatingWindow
5. UpdateNotesFromFloatingWindow
6. CompleteTaskFromFloatingWindow
7. PauseTaskFromFloatingWindow
8. ResumeTaskFromFloatingWindow
9. EditTaskFromFloatingWindow (handled differently)
10. UpdateTaskFromFloatingWindow
11. SetCountdownFromFloatingWindow
12. ClearCountdownFromFloatingWindow
13. CreateTaskFromFloatingWindow
14. SwitchTaskFromFloatingWindow (handled via onTaskSwitch closure)
15. CloseFloatingWindow (handled via FloatingWindowManager)

### 6. TodoViewModel.swift - Updated toggleTimer Method

Updated `toggleTimer()` to use the new simplified `showFloatingWindow()` signature:

**Before:**
```swift
FloatingWindowManager.shared.showFloatingWindow(
    for: todos[index],
    allTodos: todos,
    activateReminders: activateReminders,
    showTimeWhenCollapsed: showTimeWhenCollapsed,
    autoPlayAfterSwitching: autoPlayAfterSwitching,
    autoPauseAfterMinutes: autoPauseAfterMinutes,
    onTaskSwitch: { [weak self] newTask in
        self?.switchToTask(newTask)
    }
)
```

**After:**
```swift
FloatingWindowManager.shared.showFloatingWindow(for: todos[index], viewModel: self)
```

## Line Count Changes

| File | Before | After | Change |
|------|--------|-------|--------|
| ContentView.swift | ~889 lines | ~511 lines | **-378 lines** |
| TodoViewModel.swift | ~560 lines | ~834 lines | **+274 lines** |
| FloatingWindowManager.swift | ~122 lines | ~109 lines | **-13 lines** |
| FloatingTaskWindowView.swift | ~1,377 lines | ~1,257 lines | **-120 lines** |
| NotesEditorView.swift | ~76 lines | ~78 lines | **+2 lines** |

**Total reduction: ~235 lines** (primarily from ContentView)

## Architecture Improvements

### Before Phase C
```
ContentView (holds state)
    |
    | NotificationCenter (15 handlers, ~378 lines)
    |
FloatingTaskWindowView (posts 15 notifications)
```

### After Phase C
```
ContentView
    |
    | Shared ViewModel
    |
TodoViewModel (single source of truth)
    |
    | Direct method calls
    |
FloatingTaskWindowView
```

## Benefits

1. **Eliminated Boilerplate**: Removed ~378 lines of NotificationCenter plumbing
2. **Type Safety**: Direct method calls provide compile-time type checking vs. runtime dictionary access
3. **Better Testability**: ViewModel methods can be easily unit tested
4. **Simplified Data Flow**: Single source of truth (TodoViewModel) instead of bidirectional notification system
5. **Cleaner Code**: No more string-based notification names and userInfo dictionaries
6. **Reduced Coupling**: FloatingTaskWindowView now depends only on TodoViewModel, not ContentView
7. **Improved Performance**: Direct method calls are faster than NotificationCenter

## Testing Recommendations

After Phase C, thoroughly test the following in the floating window:

1. ✅ Toggle subtask completion
2. ✅ Add new subtask
3. ✅ Delete subtask
4. ✅ Toggle subtask timer
5. ✅ Edit task notes
6. ✅ Complete task
7. ✅ Pause/resume task
8. ✅ Edit task fields
9. ✅ Set countdown timer
10. ✅ Clear countdown timer
11. ✅ Create new task from floating window
12. ✅ Switch between tasks
13. ✅ Reminder functionality (if enabled)
14. ✅ Auto-pause on inactivity (if enabled)

## Next Steps: Phase D

Phase D will focus on extracting sub-views from ContentView to further reduce its size:
- Extract TaskListToolbar
- Extract TaskListItem
- Extract CompletedTasksSection

This will bring ContentView down to ~250-350 lines of clean, composable view code.
