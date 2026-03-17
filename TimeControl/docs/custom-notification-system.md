# Custom Notification System

Replace `UNUserNotificationCenter` with our own overlay window and in-process scheduler. Since TimeControl lives in the menu bar and stays running, we don't need the OS to wake us — we just need to fire UI at the right moment ourselves.

---

## Goals

- Full control over notification UI (layout, buttons, colors, sizing)
- No dependency on macOS notification permissions or system notification style settings
- Action buttons (Start Task, Snooze) always directly visible — no "Options" hiding
- Notifications fire at the start of the target minute
- Queue multiple simultaneous reminders gracefully
- Works for as long as the menu bar app is running (acceptable trade-off)
- Notification stays "active" (bell lit) until the task is started and the bell is manually dismissed
- Completing a task automatically clears its active notification state
- History widget shows past fired notifications with relative timestamps ("2 hours ago")

## Trade-offs vs UNUserNotificationCenter

| | Custom | UNUserNotificationCenter |
|---|---|---|
| Works when app is quit | No | Yes |
| Permission prompt required | No | Yes |
| Full UI control | Yes | No |
| Action buttons always visible | Yes | Hidden under "Options" |
| Reliable minute-boundary firing | Yes (our timer) | Varies |

Since TimeControl is a persistent menu bar app, the "app must be running" constraint is acceptable.

---

## Architecture

### New Files

```
Services/
  NotificationScheduler.swift      — replaces ReminderService; owns the timer loop
  NotificationStore.swift          — persists notification history and active bell state
WindowManagement/
  NotificationWindowManager.swift  — manages the overlay NSPanel
Views/
  NotificationOverlayView.swift    — SwiftUI content shown in the overlay
  NotificationHistoryView.swift    — history widget listing past notifications
```

### Modified Files

- `AppDelegate.swift` — swap `ReminderService` calls for `NotificationScheduler`
- `TodoViewModel.swift` — call `NotificationScheduler` on reminder set/cancel/complete
- `TodoItem.swift` — add `hasActiveNotification: Bool` field
- `ReminderService.swift` — can be deleted once migration is complete

---

## Components

### 1. NotificationScheduler

Replaces `ReminderService`. Owns a single `Timer` that fires every 30 seconds and checks whether any pending reminder's target minute has arrived.

**Responsibilities:**
- `schedule(_ task: TodoItem)` — store reminder in an in-memory dict keyed by `task.id`; snap the target time to the start of the minute (zero out seconds)
- `cancel(for id: UUID)` — remove from dict
- `rescheduleAll(_ todos: [TodoItem])` — called on launch; rebuilds the dict from persisted todo data; skips past reminders
- Internal timer loop — every 30s, compare `Date()` to each pending reminder's target minute; fire any that match (target minute == current minute) and remove them from the dict

**Snapping to minute boundary:**
```swift
var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
comps.second = 0
let snapped = Calendar.current.date(from: comps)!
```

**Why poll every 30s instead of scheduling exact timers per reminder:**
- Simpler — one timer to manage vs N timers
- Resilient to system sleep/wake which can skew `Timer` fire times
- 30s worst-case latency is acceptable; checking `minute == minute` naturally fires once per minute window

### 2. NotificationWindowManager

Singleton that owns an `NSPanel` and a queue of pending notification payloads.

**Responsibilities:**
- `show(_ payload: NotificationPayload)` — enqueue; show immediately if nothing is visible, otherwise queue
- `dismiss()` — close current overlay; dequeue and show next if any
- Positions the panel in the bottom-right corner of the main screen (mirroring where system notifications appear)
- Auto-dismiss timer (e.g. 8 seconds) that calls `dismiss()` unless the user is hovering

**Panel setup:**
- `NSPanel` with `.nonactivatingPanel` so it doesn't steal focus
- `NSWindowLevel.floating` so it appears above other windows
- No title bar, no shadow chrome — custom SwiftUI surface only
- `collectionBehavior = [.canJoinAllSpaces, .stationary]` so it persists across Spaces

### 3. NotificationOverlayView

SwiftUI view hosted in the panel via `NSHostingController`.

**Layout:**
```
┌─────────────────────────────────────┐
│  ⏰  Start: Fix login bug           │
│      Your reminder to begin         │
│                                     │
│  [Start Task]          [Snooze 30m] │
└─────────────────────────────────────┘
```

- Both buttons always fully visible — no hiding
- "Start Task" triggers `viewModel.switchToTask(byId:)` + opens main window + dismisses
- "Snooze 30m" calls `NotificationScheduler.schedule()` with `Date() + 30*60` + dismisses
- Tapping anywhere else on the card dismisses
- Subtle slide-in/slide-out animation

### 4. NotificationPayload

Simple value type passed from scheduler → window manager:

```swift
struct NotificationPayload {
    let taskId: UUID
    let title: String
    let body: String
}
```

### 5. NotificationRecord

Persisted entry in notification history:

```swift
struct NotificationRecord: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let taskTitle: String
    let firedAt: Date
    var isDismissed: Bool   // true once bell is manually clicked or task is completed
}
```

### 6. NotificationStore

Persists `[NotificationRecord]` to disk (JSON, same pattern as `TodoStorage`).

**Responsibilities:**
- `append(_ record: NotificationRecord)` — called when a notification fires; sets `isDismissed = false`
- `dismiss(taskId: UUID)` — marks matching records as dismissed (called on bell click or task completion)
- `records` — published array, sorted newest-first, used by the history widget
- Prune records older than 30 days on load

### 7. Bell State on TodoItem

Add `hasActiveNotification: Bool` to `TodoItem` (not persisted — derived from `NotificationStore`):

- Set to `true` when `NotificationScheduler` fires for that task
- Set to `false` when the user clicks the bell icon OR the task is marked complete
- Drives the bell icon appearance in `TodoRow` / `FloatingTaskWindowView`

**Bell icon behaviour:**
- Unlit bell (🔔 dim) — reminder is set but hasn't fired yet
- Lit/highlighted bell (🔔 active) — notification has fired and is unacknowledged
- No bell — no reminder set
- Clicking the lit bell → calls `NotificationStore.dismiss(taskId:)` → bell goes dim/off

### 8. NotificationHistoryView

Widget (e.g. a popover or sidebar section) listing past `NotificationRecord`s.

**Layout per row:**
```
🔔  Fix login bug                    2 hours ago
    [dismissed]

🔔  Review PR #42                    just now  ← active (bell lit)
```

- Relative timestamps using `RelativeDateTimeFormatter` (e.g. "just now", "3 hours ago", "yesterday")
- Active (undismissed) records shown with a highlighted bell and no `[dismissed]` label
- Clicking an active row opens the task and dismisses the bell
- Clicking a dismissed row just opens the task
- Empty state: "No past notifications"

---

## Data Flow

```
TodoViewModel.setReminder(date, for: taskId)
    → NotificationScheduler.schedule(task)              // stores in pending dict

NotificationScheduler timer fires (every 30s)
    → finds tasks whose snapped time == current minute
    → NotificationStore.append(record)                  // log to history
    → TodoItem.hasActiveNotification = true             // light up the bell
    → NotificationWindowManager.show(payload)           // show overlay

User clicks "Start Task" in overlay
    → TodoViewModel.switchToTask(byId:)
    → NotificationWindowManager.dismiss()
    // bell stays lit until user explicitly clicks it

User clicks bell icon (lit) on task
    → NotificationStore.dismiss(taskId:)
    → TodoItem.hasActiveNotification = false            // bell goes off

User clicks "Snooze 30m" in overlay
    → NotificationScheduler.schedule(task, at: now + 30min)
    → NotificationWindowManager.dismiss()
    // bell stays lit (reminder re-queued but current notification unacknowledged)

Task marked complete (any path)
    → NotificationStore.dismiss(taskId:)                // auto-dismiss bell
    → TodoItem.hasActiveNotification = false
```

---

## Launch Behaviour

On `applicationDidFinishLaunching`:

1. `NotificationScheduler.shared.rescheduleAll(viewModel.todos)` — rebuild pending dict
2. Skip any reminder whose target time is already in the past
3. Optionally: if a reminder was missed by < 5 minutes (e.g. app was just relaunched), fire it immediately anyway

---

## Bell Lifecycle Summary

| Event | Bell state | History record |
|---|---|---|
| Reminder set, not yet fired | dim (pending) | none |
| Notification fires | lit (active) | added, `isDismissed = false` |
| User clicks lit bell | off | `isDismissed = true` |
| User clicks "Start Task" in overlay | lit (still active) | unchanged |
| Task started AND bell clicked | off | `isDismissed = true` |
| Task completed (any path) | off | `isDismissed = true` |
| Snooze clicked | lit (re-queued) | existing record unchanged |

---

## What to Remove

- `ReminderService.swift` — delete after migration
- `UNUserNotificationCenter` delegate methods in `AppDelegate.swift`
- `UserNotifications` import everywhere
- `scheduleTestNotification()` in `AppDelegate` — replace with a local debug trigger if needed
- `aps-environment` was already removed from the entitlements file

---

## Implementation Order

1. `NotificationPayload` + `NotificationRecord` structs (trivial)
2. `NotificationStore` — persistence + publish (no UI dependency)
3. `NotificationScheduler` — timer loop + dict management; calls `NotificationStore.append`
4. Add `hasActiveNotification` to `TodoItem`; wire `TodoViewModel` to set/clear it
5. Bell icon in `TodoRow` / `FloatingTaskWindowView` — dim vs lit states + click handler
6. `NotificationOverlayView` — SwiftUI view with mock data first
7. `NotificationWindowManager` — wire panel + hosting controller + queue
8. `NotificationHistoryView` — reads from `NotificationStore.records`; surface it somewhere (popover from menu bar icon or sidebar)
9. Connect `TodoViewModel.toggleComplete` → `NotificationStore.dismiss`
10. Wire `AppDelegate` — remove `UNUserNotificationCenter`, add `rescheduleAll` on launch
11. Delete `ReminderService.swift`
