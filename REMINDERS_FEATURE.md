# Reminders Feature — Design Doc

> "Remind me to start this task at X time"
> Similar to Slack's **Remind me → Tomorrow 9am**

---

## Overview

A per-task reminder that fires a macOS system notification at a user-specified time, prompting you to start working on the task. The reminder is set via a **bell icon popover** directly in the UI (Option B) and also from the **Edit Task sheet** (Option C).

---

## Data Model

Add one field to `TodoItem`:

```swift
var reminderDate: Date? = nil
```

Persists automatically with the existing JSON storage. When `nil`, no reminder is set. When non-nil, a system notification is scheduled for that time.

---

## Option B — Bell Icon + Popover

A bell icon button lives in the toolbar of both:
- **`FloatingTaskWindowView`** — in the top icon row (chevron / window / notes / timer / edit / **bell**)
- **`TodoRow`** — next to the existing action buttons

### Bell Icon States

| State | Icon | Color |
|---|---|---|
| No reminder set | `bell` | blue |
| Reminder set (future) | `bell.fill` | orange |
| Reminder fired / past | `bell.slash` | secondary |

### Popover Content

Tapping the bell opens a compact popover with quick preset options:

```
┌─────────────────────────────┐
│  Set a Reminder             │
├─────────────────────────────┤
│  In 30 minutes              │
│  In 1 hour                  │
│  Later today  (5:00 PM)  *  │
│  Tomorrow morning (9:00 AM) │
│  Next Monday  (9:00 AM)     │
│  Custom…                    │
├─────────────────────────────┤
│  [Clear Reminder]       **  │
└─────────────────────────────┘
```

\* "Later today" only shown if current time < 4:30 PM
\*\* "Clear Reminder" row only shown when a reminder is currently set

**Custom** opens an inline `DatePicker` within the popover for exact date/time selection.

### After Selecting a Preset

1. Compute the target `Date` from the preset
2. Call `viewModel.setReminder(date: targetDate, for: task.id)`
3. `ReminderService.shared.schedule(task)` — schedules the `UNUserNotification`
4. Dismiss the popover
5. Bell icon updates to filled/orange immediately

---

## Option C — Edit Task Sheet

Add a **Reminder** section to `EditTodoSheet`, between the Due Date and Additional Information sections:

```
Section("Reminder") {
    Toggle("Set Reminder", isOn: $hasReminder)

    if hasReminder {
        DatePicker("Remind me at", selection: $reminderDate,
                   displayedComponents: [.date, .hourAndMinute])
    }
}
```

On Save:
- If `hasReminder` is true → `viewModel.setReminder(date: reminderDate, for: todo.id)`
- If `hasReminder` is false → `viewModel.clearReminder(for: todo.id)`

---

## ReminderService

New singleton: `Services/ReminderService.swift`

```swift
final class ReminderService {
    static let shared = ReminderService()

    func requestPermission()
    func schedule(_ task: TodoItem)           // schedules UNUserNotification
    func cancel(for taskId: UUID)             // cancels by id string
    func rescheduleAll(_ todos: [TodoItem])   // called on app launch
}
```

Uses `UNUserNotificationCenter`. Notification identifier = `task.id.uuidString`.

### Notification Payload

- **Title:** `Start: [task name]`
- **Body:** `Your reminder to begin this task`
- **Actions:**
  - `"Start Task"` — foreground action, deep-links to task
  - `"Snooze 30 min"` — background action, reschedules +30 min

### Permission Request

Request `UNUserNotificationCenter` authorization on first reminder set (not on app launch) to avoid permission fatigue.

---

## ViewModel Methods

```swift
// TodoViewModel.swift additions
func setReminder(date: Date, for taskId: UUID)
func clearReminder(for taskId: UUID)
```

`setReminder` updates `todos[i].reminderDate`, calls `saveTodos()`, then `ReminderService.shared.schedule(task)`.
`clearReminder` sets `reminderDate = nil`, saves, then `ReminderService.shared.cancel(for: taskId)`.

---

## Auto-clear Behavior

| Trigger | Action |
|---|---|
| Task manually started | Clear reminder (no longer needed) |
| Task completed | Clear reminder |
| Task deleted | Cancel notification via `ReminderService` |
| App launches | `ReminderService.shared.rescheduleAll(todos)` |
| Reminder date is in the past | Show `bell.slash` icon, treat as expired |

---

## Visual Feedback in Task List

When `reminderDate` is set and in the future, `TodoRow` shows a secondary label below the task title (same style as due date):

```
⏰ Tomorrow, 9:00 AM
```

Rendered only in advanced mode (matching existing `isAdvancedMode` gate for due date display).

---

## Notification Response Handling

In `TimeControlApp` (or `AppDelegate`), implement `UNUserNotificationCenterDelegate`:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse) async {

    let taskIdStr = response.notification.request.identifier
    guard let taskId = UUID(uuidString: taskIdStr) else { return }

    switch response.actionIdentifier {
    case "START_TASK":
        openMainWindow()
        viewModel.switchToTask(byId: taskId)
    case "SNOOZE_30":
        viewModel.snoozeReminder(for: taskId, minutes: 30)
    default: // banner tap
        openMainWindow()
    }
}
```

---

## Implementation Status

### Done
- [x] `var reminderDate: Date? = nil` → `TodoItem`
- [x] `setReminder(_ date: Date?, for taskId: UUID)` → `TodoViewModel` (pass `nil` to clear)
- [x] Bell button + `ReminderPickerPopover` → `FloatingTaskWindowView`

### Remaining

---

### Phase 1 — Make Notifications Actually Fire
*Prerequisite for everything else. No point building more UI until the OS delivers notifications.*

#### 1. Enable User Notifications entitlement
In Xcode: **Signing & Capabilities → + → User Notifications**. This adds the required key to `TimeControl.entitlements` automatically. Without this, `UNUserNotificationCenter` auth requests are silently ignored on sandboxed apps.

#### 2. Build `ReminderService`
New file: `Services/ReminderService.swift`

```swift
import UserNotifications

final class ReminderService {
    static let shared = ReminderService()

    func requestPermission()
    func schedule(_ task: TodoItem)         // cancel existing, schedule new if reminderDate is future
    func cancel(for taskId: UUID)
    func rescheduleAll(_ todos: [TodoItem]) // call on app launch
}
```

- Notification category `"TASK_REMINDER"` with two actions: `"START_TASK"` (foreground) and `"SNOOZE_30"` (background)
- Register the category once in `requestPermission` / app init
- Identifier per notification = `task.id.uuidString`

#### 3. Wire `ReminderService` into `TodoViewModel.setReminder`
After saving, call `ReminderService.shared.schedule(todos[idx])` (or `.cancel` when `date == nil`).

---

### Phase 2 — Complete the Core Loop
*Reminders survive app restarts and respond to user actions.*

#### 4. App launch reschedule
In `TimeControlApp.init` or `onAppear` of `ContentView`:
```swift
ReminderService.shared.rescheduleAll(viewModel.todos)
```

#### 5. Notification response handler
In `TimeControlApp`, conform to `UNUserNotificationCenterDelegate` and handle:
- `"START_TASK"` → `openMainWindow()` + `viewModel.switchToTask(byId:)`
- `"SNOOZE_30"` → `viewModel.setReminder(Date().addingTimeInterval(30*60), for: taskId)`
- Default (banner tap) → `openMainWindow()`

Also add a `switchToTask(byId:)` helper to `TodoViewModel` if not present.

---

### Phase 3 — UI Coverage
*Reminders accessible from anywhere in the app, not just the floating window.*

#### 6. Bell button → `TodoRow`
Same bell button pattern as `FloatingTaskWindowView`. Add `onSetReminder: (Date?) -> Void` callback to `TodoRow`, wire it in `ContentView`, show the popover.

#### 7. Reminder section → `EditTodoSheet` (Option C)
Add between Due Date and Additional Information sections:
```swift
Section("Reminder") {
    Toggle("Set Reminder", isOn: $hasReminder)
    if hasReminder {
        DatePicker("Remind me at", selection: $reminderDate,
                   displayedComponents: [.date, .hourAndMinute])
    }
}
```
On save: call `viewModel.setReminder(hasReminder ? reminderDate : nil, for: todo.id)`.

#### 8. `⏰` label in `TodoRow` (advanced mode)
When `todo.reminderDate` is set and in the future, show below the task title (same style as due date):
```swift
if isAdvancedMode && !isExpanded, let reminder = todo.reminderDate, reminder > Date() {
    Label(TimeFormatter.formatDueDate(reminder), systemImage: "bell.fill")
        .font(.subheadline)
        .foregroundColor(.orange)
}
```

---

### Phase 4 — Polish & Lifecycle
*Clean state management so reminders don't linger after they're no longer relevant.*

#### 9. Auto-clear on task start / complete / delete
In `TodoViewModel`:
- `toggleTimer(_:)` — when starting a task, call `setReminder(nil, for: id)` if `reminderDate != nil`
- `completeTodo(_:)` — same
- `deleteTodo(_:)` — call `ReminderService.shared.cancel(for: id)` before removing
