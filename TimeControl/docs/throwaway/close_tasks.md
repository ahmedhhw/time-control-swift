# Close Tasks Without Completing Feature Design

## Overview

This feature allows users to close tasks in TimeControl without marking them as completed. This is useful for tasks that are canceled, abandoned, or no longer relevant, but should not be considered "done" in the system (e.g., Azure DevOps work items).

## Requirements

- Add a "Close Task" action to task management UI
- Close the task sets its state to "Closed" (or appropriate non-completed state) in ADO
- Remove the task from active task lists in TimeControl
- Provide confirmation dialog to prevent accidental closes
- Log the close action for audit purposes
- Handle subtasks: closing a parent task should offer to close subtasks as well

## UI Design

### Task Context Menu

In the main task list view, right-clicking on a task shows a context menu with options including "Close Task".

```
+-----------------------------+
| Task: Implement login flow  |
| Status: In Progress         |
| Time: 2h 30m               |
+-----------------------------+
| [Complete Task]             |
| [Close Task]                |  <-- New option
| [Edit Task]                 |
| [View History]              |
+-----------------------------+
```

### Close Task Confirmation Dialog

When selecting "Close Task", show a confirmation dialog with options.

```
+-----------------------------------+
| Close Task                        |
+-----------------------------------+
| Are you sure you want to close    |
| "Implement login flow"?           |
|                                   |
| This will set the task state to   |
| "Closed" in Azure DevOps and      |
| remove it from your active tasks. |
|                                   |
| [Cancel]          [Close Task]    |
+-----------------------------------+
```

### Bulk Close Option

For multiple selected tasks, provide a bulk close action.

```
Selected Tasks: 3
+-----------------------------+
| [ ] Task A                  |
| [ ] Task B                  |
| [ ] Task C                  |
+-----------------------------+
| [Close Selected Tasks]      |
+-----------------------------+
```

## Workflow

1. User selects task(s) to close
2. Confirmation dialog appears
3. Upon confirmation:
   - Update ADO work item state to "Closed"
   - Remove task from local active task list
   - Log the action
   - Refresh UI

## Edge Cases

- Task with subtasks: Prompt user to close subtasks too
- Task with active time session: Warn user that current session will be stopped
- Network failure: Retry ADO update or mark for later sync
- Permission issues: Show error if user lacks ADO permissions to close

## Implementation Notes

- Extend `ADOService` with `closeWorkItem(id: String, reason: String?)` method
- Add `TaskState.closed` enum case if needed
- Update `TaskViewModel` to handle close actions
- Add UI components: `CloseTaskButton`, `CloseConfirmationDialog`
- Integrate with existing notification system for success/error feedback

## ASCII Mock Designs

### Main App Body - Task List with Close Buttons

```
+-----------------------------------------------------+
| TimeControl - Main Window                           |
+-----------------------------------------------------+
| Active Tasks:                                       |
|                                                     |
| +-----------------------------------+ [Complete] [X] |
| | Task: Implement login flow        |               |
| | Status: In Progress               |               |
| | Time: 2h 30m                      |               |
| +-----------------------------------+               |
|                                                     |
| +-----------------------------------+ [Complete] [X] |
| | Task: Fix bug in timer            |               |
| | Status: In Progress               |               |
| | Time: 1h 15m                      |               |
| +-----------------------------------+               |
|                                                     |
| Closed Tasks:                                       |
|                                                     |
| +-----------------------------------+               |
| | Task: Old cancelled task          |               |
| | Status: Closed                    |               |
| | Time: 0h 45m                      |               |
| +-----------------------------------+               |
|                                                     |
+-----------------------------------------------------+
```

*Note: [X] represents the close button. Clicking it moves the task to the "Closed Tasks" section below.*

### Current Task Window - Close Button

```
+-----------------------------------------------------+
| Current Task Window                                |
+-----------------------------------------------------+
| Task: Implement login flow                         |
| Status: In Progress                                |
| Time: 2h 30m                                       |
|                                                     |
| [Start/Pause Timer] [Complete] [Close Task]        |
|                                                     |
| Description:                                        |
| Working on user authentication...                   |
|                                                     |
+-----------------------------------------------------+
```

*Note: "Close Task" button in the current task window for quick access.*

### Settings - Skip Confirmation Option

```
+-----------------------------------------------------+
| Settings Window                                    |
+-----------------------------------------------------+
| General Settings:                                  |
|                                                     |
| [ ] Show notifications                              |
| [ ] Auto-start timer on task select                 |
| [x] Skip close task confirmation                    |
|                                                     |
| ADO Integration:                                   |
|                                                     |
| Organization: ahmedhhwapps                          |
| Project: integra                                    |
|                                                     |
+-----------------------------------------------------+
```

*Note: Checkbox to enable/disable confirmation dialog when closing tasks.*

### Confirmation Dialog (When Skip Setting is Off)

```
+-----------------------------------+
| Close Task Confirmation           |
+-----------------------------------+
| Are you sure you want to close    |
| "Implement login flow"?           |
|                                   |
| This will move the task to the    |
| closed section and update Azure   |
| DevOps status to "Closed".        |
|                                   |
| [Cancel]          [Close Task]    |
+-----------------------------------+
```

*Note: Only shown when "Skip close task confirmation" is unchecked in settings.*
