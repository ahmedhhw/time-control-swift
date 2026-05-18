# TimeControl v2.0 Release Notes

🎉 Welcome to TimeControl v2.0!

TimeControl v2.0 is a major evolution of the macOS productivity app, building on the solid time-tracking foundation of v1.0 with deep enterprise integration, rich collaboration tools, and a dramatically enhanced user experience. Built entirely with native SwiftUI and AppKit, v2.0 transforms TimeControl from a personal time tracker into a full-featured productivity hub.

---

## ✨ WHAT'S NEW IN V2.0

### 🔗 Azure DevOps Integration

The flagship new feature of v2.0 is first-class Azure DevOps (ADO) integration, bringing your work items directly into your time tracking workflow.

- **Work Item Linking** — Paste an ADO URL or ID to link any task to a work item
- **Import Work Items** — Browse and import ADO items assigned to you, or fetch by ID; duplicate detection prevents re-importing existing tasks
- **Inline Comments** — Read, write, and refresh ADO work item comments without leaving the app
- **Rich Comment Composer** — Full-featured text editor for composing comments, supporting @mentions with autocomplete and image attachments
- **Image Paste in Comments** — Paste screenshots or images directly into comments; images are automatically uploaded to ADO as attachments
- **@Mention Autocomplete** — Type `@` to search and insert mentions of team members
- **Unread Comment Tracking** — Bell indicator on linked tasks shows when new comments arrive
- **Subtask Comment Prompts** — Optionally post a comment when completing a subtask
- **Secure Credential Storage** — ADO Personal Access Token (PAT) stored securely in macOS Keychain

---

### 🪟 Floating Window — Tabbed Interface

The floating timer window has been completely redesigned with a 5-tab interface:

| Tab | Contents |
|-----|----------|
| **Focus** | Task name, description, due date, estimated time — everything needed to stay on task |
| **Timers** | Countdown timer controls with elapsed/remaining display |
| **Subtasks** | Full subtask management: add, complete, reorder, and time subtasks inline |
| **Notes** | Rich text notes editor for the current task |
| **ADO** | Azure DevOps comments viewer and composer |

---

### ⌨️ Keyboard Shortcuts (13 Global Shortcuts)

All shortcuts are fully customizable via Settings.

| Action | Default Shortcut |
|--------|-----------------|
| Toggle Timer (pause/resume) | `⌘⇧I` |
| Task Switcher | `⌘L` |
| Set Countdown Timer | `⌘⇧Y` |
| Open Notes | `⌘D` |
| Complete Running Task | `⌘O` |
| Toggle Collapse Floating Window | `⌘⇧C` |
| Open Notes Viewer | `⌘⇧D` |
| Focus ADO Comment Editor | `⌘⇧A` |
| Send ADO Comment | `⌘↩` |
| Add Subtask | `⌘⇧T` |
| Open History / Calendar | `⌘⇧H` |
| Show Main Window | `⌘⇧M` |
| Command Palette | `⌘⇧L` |

---

### 🎨 Command Palette

Press `⌘⇧L` to open the Command Palette — a spotlight-style interface to search and execute any app action instantly, without hunting through menus or windows.

---

### ⚡ Task Switcher

Press `⌘L` to open the Task Switcher — a quick-access panel listing all active tasks with elapsed time. Switch tasks instantly without touching the main window.

---

### 📅 History & Calendar View

Press `⌘⇧H` to open the History view:

- **Calendar Grid** — Monthly overview with daily and weekly time totals
- **Gantt-Style Timeline** — Visual timeline for any selected day showing task sessions as color-coded bars
- **Task Breakdown** — See exactly which tasks and subtasks occupied each time block

---

### 📝 Notes System

- **Dedicated Notes Viewer** (`⌘⇧D`) — A split-pane browser for notes across all tasks; navigate tasks on the left, read and edit notes on the right
- **Notes Window** — Floating notes editor for the current task, with independently persisted window position
- **Notes in Floating Window** — Notes tab in the floating window for in-context editing

---

### 🔔 Reminders & Notifications

- **Reminder Scheduling** — Set a specific date and time to be reminded about any task
- **Notification History** — Review all past reminders in a dedicated panel
- **Snooze Options** — Dismiss reminders or snooze for 15 minutes, 30 minutes, or 1 hour
- **Rate Limiting** — Maximum 3 reminder prompts per day to avoid notification fatigue
- **Idle Activity Detection** — Monitors keyboard/mouse activity; prompts when you've been idle while a timer is running, with options to keep time, discard, or pause

---

### 🗃️ SQLite Storage

Data is now persisted in a local SQLite database instead of a flat JSON file, with automatic migration from v1 JSON format. This enables:

- Faster reads/writes for large task lists
- Reliable concurrent access
- Structured query support for history and analytics

---

### 🪟 Window Opacity Control

Adjust the transparency of the floating window and other panels to suit your workflow — keep the timer visible without fully covering what's behind it.

---

### 📦 Batch Operations (Mass Edit)

Select multiple tasks and apply bulk changes:

- **Fill** — Set a field (title, description, notes, fromWho, adhoc, estimate, due date) on all selected tasks at once
- **Edit** — Modify a specific field across all selected tasks

---

### 🔢 Enhanced Sorting

Four sort modes now available:

- Creation Date (Newest / Oldest)
- Recently Played (most recently active first)
- Due Date (nearest first)

---

## 🧩 IMPROVEMENTS TO EXISTING FEATURES

### Floating Window
- Redesigned with 5-tab layout
- Window opacity/transparency control
- Title bar accessory buttons for Notes and Settings
- Toast (HUD) notifications for quick feedback
- Smooth collapse/expand with `⌘⇧C`

### Subtask Management
- Per-subtask session tracking with start/stop history
- Auto-start next incomplete subtask when the previous one is completed (parent must be running)
- Subtask input field at the bottom of the list for natural append flow

### Timer & Sessions
- Sessions now record outcome (completed vs. discarded if too short)
- Orphaned session cleanup on app launch (handles ungraceful shutdowns)
- Sleep/wake handling ensures timer accuracy across device sleep

### Task Metadata
- `reminderDate` — schedule reminders on tasks
- `adoWorkItemId` — links to ADO work item
- `hasActiveNotification` — runtime notification state
- `lastPlayedAt` — tracks most recent activity for "recently played" sort

### Task List
- **Command Palette** integration for all actions
- **Task Switcher** for rapid task changes
- "Stay in create mode" toggle — keep input field open after adding a task
- Improved search across title, description, notes, and metadata

---

## 🔧 TECHNICAL HIGHLIGHTS

- **588 Swift source files** across views, view models, services, and tests
- **SQLite persistence** via custom `SQLiteStorage` layer with JSON migration
- **Keychain integration** for secure PAT storage
- **Testable architecture** — `IdleActivityMonitor` and other services use injectable fake timers for unit testing
- **50+ test files** covering ViewModel operations, ADO service, window management, filter/sort logic, idle detection, session tracking, and keyboard shortcuts
- **13 window managers** coordinating multi-window lifecycle
- **MVVM throughout** — all views bind to `@ObservedObject` view models; no business logic in views

---

## 📊 PROJECT STATISTICS

| Metric | V1 | V2 |
|--------|----|----|
| Total Commits | 66 | 254 |
| Source Files | ~10 | 588 |
| Keyboard Shortcuts | ~2 | 13 (customizable) |
| Floating Window Tabs | 1 | 5 |
| External Integrations | 0 | Azure DevOps |
| Persistence | JSON | SQLite |
| Test Files | 5 | 50+ |
| Window Types | 2 | 13+ |

---

## 📦 INSTALLATION

**Option 1: Build from Source**
```bash
cd TimeControl
xcodebuild -project TimeControl.xcodeproj -scheme TimeControl -configuration Release
open ~/Library/Developer/Xcode/DerivedData/TimeControl-*/Build/Products/Release/TimeControl.app
```

**Option 2: Create DMG for Distribution**
```bash
cd TimeControl
make dmg     # Create styled DMG
make install # Build DMG and open for installation
```

DMG files are created in the `dist/` directory.

**Option 3: Download the attached DMG**
Download and install `TimeControl.dmg` from the release assets, then run:
```bash
xattr -dr com.apple.quarantine /Applications/TimeControl.app
```

---

## 🚀 GETTING STARTED WITH V2

1. **Migrate from V1** — Launch the app; your existing `todos.json` is automatically imported into SQLite
2. **Connect ADO** — Open Settings → ADO, enter your organization, project, and PAT
3. **Import Work Items** — Use the ADO import dialog to pull in your assigned items
4. **Set Up Shortcuts** — Open Settings → Keyboard Shortcuts and customize to your workflow
5. **Try the Command Palette** — Press `⌘⇧L` to discover all available actions

---

## 🎯 USE CASES

**Software Developers**
- Link tasks to ADO work items, read/post comments without context-switching
- Track time per ticket with session history
- Use History view to review daily coding sessions

**Team Leads / Project Managers**
- Import assigned ADO items for the day
- Post subtask completion updates as ADO comments
- Review team members via @mentions

**Freelancers**
- Track billable time per client task
- Export to CSV for invoicing
- Use reminders for deadline follow-ups

**Deep Work Practitioners**
- Use idle detection to catch untracked distraction time
- Gantt history view to review focus patterns
- Task Switcher for rapid context switches without losing flow

---

## 🔒 LICENSE

TimeControl is licensed under **GNU AGPL-3.0**. All modifications and derivative works must be shared under the same license.

---

## 🔮 LOOKING AHEAD

Potential future directions:

- Time reports and analytics dashboard
- iCloud or self-hosted sync
- iOS/iPadOS companion app
- Additional integrations (Jira, Linear, GitHub Issues)
- Task priority levels and tagging
- Recurring task templates
- Undo/redo stack

---

## 🙏 ACKNOWLEDGMENTS

Built with:

- **SwiftUI** — Declarative UI framework
- **AppKit** — Advanced window management (NSPanel, NSTextView)
- **SQLite** — Local database persistence
- **Foundation** — Core functionality
- **Security / Keychain** — Secure credential storage
- **AVFoundation** — Audio alerts for countdown completion
- **UserNotifications** — Reminder scheduling

---

*Built with ❤️ for macOS using SwiftUI*

*For usage instructions, troubleshooting, and API documentation, see the comprehensive README.md.*
