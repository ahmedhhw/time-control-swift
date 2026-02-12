# TimeControl - macOS Todo List with Time Tracking

A comprehensive macOS todo list application built with SwiftUI, featuring advanced time tracking, task management, and productivity tools.

## Overview

TimeControl is a native macOS application designed for productivity and time management. It combines traditional task management with sophisticated time tracking capabilities, including a floating timer window that stays visible across all applications. The app features hierarchical task organization with subtasks, detailed task metadata, and comprehensive timestamp tracking for analytics.

**Key Highlights:**
- 🪟 **Floating Timer Window** - stays on top across all spaces and applications
- ⏱️ **Precise Time Tracking** - track time spent on each task with play/pause controls
- 📋 **Hierarchical Tasks** - unlimited subtasks with independent completion tracking
- 💾 **Auto-Save** - all changes persist immediately to JSON storage
- 🎯 **Progress Tracking** - visual progress bars comparing actual vs. estimated time
- 📊 **Detailed Timestamps** - created, started, and completed timestamps for analytics
- 🎨 **Native macOS UI** - respects system appearance (light/dark mode)

## Features

### Core Task Management
- ✨ Add todo items via a text field at the top
- ✅ Mark todos as complete/incomplete with a checkbox
- 📜 Scrollable list view for all your todos
- 🗑️ Delete todos with a trash button
- ✏️ Edit task details with a dedicated edit dialog
- 🔄 Drag and drop to reorder tasks
- 📂 Collapsible completed tasks section

### Time Tracking
- ⏱️ Built-in timer for each task
- ⏸️ Play/pause timer functionality
- 📊 Automatic time accumulation - see total time spent on each task
- 🔄 **Single-task timer** - only one task can have a running timer at a time (others auto-pause)
- ⏹️ **Auto-pause on completion** - timer automatically stops when task is marked complete
- 🕒 **Real-time display** - timer updates every second in both main window and floating window
- 🪟 **Floating window** - timer opens a small floating window that stays on top of all applications
- 🎯 Floating window features:
  - Always visible across all spaces/desktops
  - Shows current task name, description, and subtasks
  - Collapsible/expandable design with animated transitions
  - Check off subtasks directly from the floating window
  - Take notes while working on the task
  - Progress bar showing time elapsed vs. estimated time (when estimate is set)
  - Over-time indicator with visual warning when task exceeds estimate
  - Complete task button to mark as done from floating window
  - Resizable and movable (positioned at bottom-right by default)

### Subtasks
- 📋 Add unlimited subtasks to any task
- ✅ Mark subtasks as complete/incomplete
- 🗑️ Delete individual subtasks
- 🔽 Expandable/collapsible subtask view with chevron indicator
- 🎯 Quick subtask entry with auto-focus for rapid task breakdown
- 📝 Subtask counter badge showing number of subtasks
- 🔄 Subtasks sync between main window and floating window in real-time
- 💬 Each subtask has title and optional description fields
- 🔒 Subtasks become read-only when parent task is completed
- ⚡ Inline editing experience with instant focus after adding a subtask

### Task Details & Metadata
- 📝 **Task title and description** - add detailed context to tasks
- 📅 **Due date and time** - set deadlines with calendar picker (date and hourAndMinute components)
- ⚡ **Adhoc task flag** - mark tasks that came up unexpectedly
- 👤 **"From who" field** - track who assigned or requested the task
- ⏳ **Estimated time** - set time estimates with separate hour (0-23) and minute (0-59) pickers
- 📓 **Task notes** - take detailed notes while working on a task (accessible from floating window)
- 🎨 **Rich text editing** - multi-line TextEditor for descriptions and notes
- 📋 **Comprehensive edit sheet** - modal form with all task properties organized in sections

### Timestamps & Analytics
- 🕐 **Created timestamp** - when the task was created (epoch time)
- ▶️ **Started timestamp** - when the timer was first started (epoch time, set once)
- ✅ **Completed timestamp** - when the task was marked complete (epoch time)
- 📊 All timestamps displayed in readable format (date and time)
- 🔄 **Timestamps persist** - cleared when task is marked incomplete again

### Data Synchronization
- 🔔 **NotificationCenter-based sync** - real-time communication between main window and floating window
- 🔄 **Three-way sync events**:
  - `ToggleSubtaskFromFloatingWindow` - syncs subtask completion from floating window to main app
  - `UpdateNotesFromFloatingWindow` - syncs notes from floating window to main app
  - `CompleteTaskFromFloatingWindow` - completes task from floating window
- ⚡ **Instant updates** - changes in floating window immediately reflected in main window
- 💾 **Auto-save on sync** - every sync event triggers a save to persistent storage
- 🔄 **Task state updates** - floating window receives updates when subtasks are added/modified in main window

### UI/UX Features
- 💾 **Persistent storage** - all data automatically saved to JSON and restored on app launch
- 🎨 Modern macOS UI with native styling
- 🌓 Respects system light/dark mode
- ⚡ Real-time UI updates for running timers (updates every second)
- 🎯 Focused input experience with automatic text field management
- 🔔 Visual indicators for running timers (blue color for active timers)
- 🚫 Automatic timer pause when task is completed
- 🎭 Smooth spring animations for expand/collapse and reordering
- 🖱️ **Drag and drop reordering** - intuitive task reordering with drag gestures
- 📍 **Drop zone at end** - dedicated drop area for moving tasks to the last position
- 🔒 **Completed task protection** - editing, timing, and deletion disabled for completed tasks (except uncompleting)
- 📱 **Responsive layout** - minimum window size of 400x300, resizable to user preference
- 🎯 **Context-aware controls** - buttons and fields adapt based on task state (completed/incomplete)
- ⏱️ **Monospaced digits** - consistent time display using monospaced font
- 🔢 **Smart time formatting** - shows HH:MM:SS for hours, MM:SS otherwise
- 📋 **Lazy loading** - efficient rendering with LazyVStack for large task lists
- 🎪 **Smooth transitions** - combined opacity and move animations for state changes
- 🪟 **Non-intrusive floating window** - becomesKeyOnlyIfNeeded, non-activating panel behavior

## How to Run

### Option 1: Using Xcode (GUI)

1. Open `TimeControl/TimeControl.xcodeproj` in Xcode
2. Make sure the target is set to "My Mac" or your Mac device
3. Press `Cmd + R` to build and run the app

Alternatively, you can open the project from Finder by double-clicking the `TimeControl.xcodeproj` file.

### Option 2: Using Command Line (without Xcode IDE)

**Prerequisites**: Xcode Command Line Tools must be installed:
```bash
xcode-select --install
```

**Build and run the app:**

```bash
cd TimeControl
xcodebuild -project TimeControl.xcodeproj -scheme TimeControl -configuration Debug
open ~/Library/Developer/Xcode/DerivedData/TimeControl-*/Build/Products/Debug/TimeControl.app
```

**Or build a release version:**

```bash
cd TimeControl
xcodebuild -project TimeControl.xcodeproj -scheme TimeControl -configuration Release
open ~/Library/Developer/Xcode/DerivedData/TimeControl-*/Build/Products/Release/TimeControl.app
```

**One-liner to build and run:**

```bash
cd TimeControl && xcodebuild -project TimeControl.xcodeproj -scheme TimeControl -configuration Debug && open ~/Library/Developer/Xcode/DerivedData/TimeControl-*/Build/Products/Debug/TimeControl.app
```

## Build a DMG (Distribution)

### Quick Start with Make

The easiest way to create a DMG is using the Makefile:

```bash
cd TimeControl
make dmg              # Create styled DMG
make dmg-quick        # Create DMG without styling (faster)
make dmg-version VERSION=1.0.0  # Create versioned DMG
make release          # Clean build + create DMG
```

### Using the Script Directly

You can also use the build script directly with more options:

```bash
cd TimeControl
./scripts/make-dmg.sh                    # Basic DMG creation
./scripts/make-dmg.sh --version 1.0.0    # Versioned DMG
./scripts/make-dmg.sh --skip-build       # Use existing build
./scripts/make-dmg.sh --no-style         # Skip Finder styling
./scripts/make-dmg.sh --help             # Show all options
```

### Available Make Targets

```bash
make help           # Show all available commands
make build          # Build release version
make run            # Build and run the app
make clean          # Clean build artifacts
make info           # Show project information
make install        # Build DMG and open for installation
```

### Output

DMG files are created in the `dist/` directory:
- Default: `dist/TimeControl.dmg`
- Versioned: `dist/TimeControl-1.0.0.dmg`

For more details, see `TimeControl/scripts/README.md`

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later (for building from source)
- No external dependencies required

## Limitations & Design Decisions

### By Design
- **Single timer**: Only one task can have an active timer at a time (others auto-pause)
- **Read-only completed tasks**: Edit, timer, and delete operations disabled for completed tasks (prevents accidental modifications)
- **No subtask editing**: Subtasks can be deleted and recreated but not edited in-place (simplified workflow)
- **Timer doesn't persist as running**: Running timers stop when app quits (accumulated time is saved)
- **No categories/tags**: Tasks organized solely by incomplete/completed status
- **No cloud sync**: All data stored locally in JSON file
- **No recurring tasks**: Each task is unique, no repeat scheduling
- **No notifications**: No reminders or due date alerts

### Current Implementation
- **Manual reordering only**: No automatic sorting by due date, priority, or time
- **Single window**: Cannot open multiple main windows (floating window is separate)
- **No task search**: Filter or search functionality not implemented
- **No task export**: Cannot export tasks to other formats (CSV, PDF, etc.)
- **No multi-select**: Cannot select and operate on multiple tasks at once
- **No undo/redo**: Changes are immediate and permanent (except for canceling edit dialogs)

## Usage

### Keyboard Shortcuts

#### Main Window
- **Enter**: Submit new todo or new subtask (when in respective text fields)
- No other global keyboard shortcuts (mouse-driven interface)

#### Edit Task Sheet
- **Cmd + Return**: Save changes
- **Cmd + .**: Cancel and close without saving

#### Notes Editor
- **Cmd + Return**: Save notes
- **Cmd + .**: Cancel and close without saving

### Basic Operations
- **Add a todo**: Type in the text field at the top and press Enter or click the + button
- **Mark as complete**: Click the circle icon next to a todo item
- **Delete a todo**: Click the trash icon on the right side of a todo item
- **Edit a todo**: Click the pencil icon to open the edit dialog

### Time Tracking
- **Start timer**: Click the play button (▶️) next to a task
  - Opens a floating window that stays on top
  - Timer continues accumulating time
  - Only one timer can run at a time
- **Pause timer**: Click the pause button (⏸️) to stop the timer
- **View time spent**: Time is displayed below the task title in HH:MM:SS or MM:SS format

### Subtask Management
- **Expand task**: Click the chevron icon (›) to show subtask area
- **Add subtask**: Type in the subtask field and press Enter or click the + button
- **Complete subtask**: Click the circle icon next to a subtask
- **Delete subtask**: Click the trash icon next to a subtask
- **Collapse task**: Click the chevron icon (⌄) to hide subtasks

### Floating Window
- **Auto-opens** when you start a timer
- **Auto-closes** when the timer is paused or task is completed
- **Positioned** at bottom-right of screen with 20px padding by default
- **Take notes**: Click the "Notes" button to open the notes editor
- **Check subtasks**: Toggle subtask completion directly from the floating window
- **Collapse/expand**: Click the chevron at the top to minimize (50px height) or maximize (400px height)
- **Animated resizing**: Smooth animations when collapsing/expanding
- **Always on top**: Stays visible across all applications and desktops (`.floating` window level)
- **Progress tracking**: Visual progress bar when task has estimated time set
- **Over-time warnings**: Orange indicator when task exceeds estimated time
- **Remaining time**: Shows how much time is left before hitting the estimate
- **Scrollable subtasks**: Subtask list scrolls if there are many items
- **Complete from window**: Green "Complete" button at bottom to finish task without switching windows
- **Resizable**: Minimum size of 100x30, can be resized by user
- **Multi-space support**: Works across all macOS Spaces and fullscreen apps

### Task Details
- **Edit task details**: Click the pencil icon to open the edit sheet where you can:
  - Change the task title
  - Add/edit description (multi-line text editor with scrollable area)
  - Set estimated time with hour (0-23) and minute (0-59) pickers
  - Set due date and time (toggle to enable/disable, date picker with date and time)
  - Mark as adhoc task (boolean toggle)
  - Add "from who" information (text field)
  - View created, started, and completed timestamps (read-only, formatted display)
- **Modal dialog**: Edit sheet appears as a modal window (500x500 minimum size)
- **Keyboard shortcuts**: Save with Cmd+Return, Cancel with Cmd+.
- **Form validation**: Save button disabled if task title is empty
- **Organized sections**: Task Details, Timestamps, Estimate, Due Date, Additional Information

### Organization
- **Reorder tasks**: Drag and drop tasks to change their order (works in both incomplete and completed sections)
- **Auto-reindexing**: Task indices automatically updated after reordering
- **View completed**: Click the "Completed" section header to expand/collapse completed tasks
- **Completed tasks** are automatically moved to a separate collapsible section at the bottom
- **Completed section styling**: Distinct visual styling with count badge showing number of completed tasks
- **Scrollable sections**: Both incomplete and completed sections scroll independently
- **Max height for completed**: Completed section limited to 300px height with internal scrolling
- **Empty state**: Helpful message when no tasks exist ("No todos yet" with subtitle)
- **Preserved during drag**: Task expansion state and subtasks preserved during reordering
- **Visual feedback**: Dragged items show with 80% opacity during drag operation

### Important Behaviors

#### Task Completion
- When a task is marked as complete:
  - Timer automatically pauses (if running)
  - Floating window closes
  - completedAt timestamp is set
  - Task moves to completed section
  - Edit, timer, and delete buttons are disabled
  - Subtask deletion is disabled
- When a task is uncompleted:
  - completedAt timestamp is cleared
  - Task moves back to incomplete section
  - All controls re-enabled

#### Timer Behavior
- Only one task can have a running timer at a time
- Starting a timer on one task automatically pauses all other timers
- Running timers show in blue color, paused timers show accumulated time in secondary color
- Time continues to accumulate across multiple start/stop cycles
- Timer state persists across app restarts (though timer stops, accumulated time is saved)

#### Subtask Management
- Subtasks cannot be added to completed tasks (input not shown)
- Subtasks cannot be deleted from completed tasks
- Subtasks can still be viewed when task is completed
- Subtask changes sync to floating window if parent task is running
- Adding a subtask auto-focuses input for quick successive additions

#### Floating Window
- Opens automatically when timer starts
- Closes automatically when timer pauses or task completes
- Window position maintained by system across app launches
- Collapsing reduces height to 50px, expanding returns to 400px
- Window stays on top even during fullscreen apps
- Completing task from floating window closes the window immediately

#### Data Persistence
- Saves automatically after every change (add, edit, delete, complete, reorder)
- No manual save required
- File location: `~/Documents/todos.json`
- Data loads automatically on app launch
- No data loss on unexpected quit (last save persists)

## Project Structure

```
TimeControl/
├── TimeControl.xcodeproj/          # Xcode project file
├── TimeControl/
│   ├── TimeControlApp.swift        # Main app entry point
│   ├── ContentView.swift       # Main UI with all components:
│   │                           #   - TodoItem & Subtask models
│   │                           #   - TodoStorage (JSON persistence)
│   │                           #   - ContentView (main app view)
│   │                           #   - TodoRow (task display)
│   │                           #   - EditTodoSheet (task editor)
│   │                           #   - SubtaskRow (subtask display)
│   │                           #   - FloatingWindowManager (floating window controller)
│   │                           #   - FloatingTaskWindowView (floating window UI)
│   │                           #   - NotesEditorView (notes editor)
│   ├── TimeControl.entitlements    # App permissions
│   ├── Assets.xcassets/        # App icons and colors
│   └── Preview Content/        # SwiftUI preview assets
├── Makefile                    # Build automation commands
├── scripts/
│   ├── make-dmg.sh             # DMG creation script with styling
│   ├── quick-dmg.sh            # Fast DMG creation without styling
│   └── README.md               # Script documentation
├── dist/                       # Output directory for DMG files
├── DMG_CREATION_GUIDE.md       # Comprehensive DMG creation guide
└── QUICK_REFERENCE.md          # Quick reference for common tasks
```

## Code Overview

The app uses SwiftUI and consists of several key components:

### Data Models
- **TodoItem**: A comprehensive struct representing a task with:
  - Basic info: ID, text, completion status, index
  - Time tracking: totalTimeSpent, lastStartTime, startedAt, completedAt
  - Details: description, dueDate, estimatedTime, notes
  - Metadata: isAdhoc, fromWho, createdAt
  - Relationships: subtasks array
- **Subtask**: A struct for subtasks with ID, title, description, and completion status

### Storage
- **TodoStorage**: Static class for JSON persistence to `~/Documents/todos.json`
  - Saves all task data including subtasks, timestamps, and metadata
  - Loads and restores tasks on app launch
  - Maintains task order using index field
  - Uses `FileManager` to locate Documents directory
  - Converts tasks to dictionary format: `{ "tasks": { "uuid": { ...taskData } } }`
  - Pretty-printed JSON for readability
  - Handles optional fields (dueDate, lastStartTime, startedAt, completedAt)
  - Serializes subtasks as nested arrays with all properties
  - Error handling with console logging
  - Returns empty array if file doesn't exist (first launch)

### Views
- **ContentView**: The main view with:
  - Task list management (incomplete and completed sections)
  - Timer management and UI updates (receives timer events every second)
  - Drag and drop reordering with drop destinations
  - Notification handling for floating window communication (3 notification types)
  - State management for expanded tasks, focused inputs, and running task ID
  - Computed properties to separate incomplete and completed todos
  - Sheet presentation for edit dialog
- **TodoRow**: Displays individual tasks with:
  - Completion toggle (green checkmark when complete)
  - Timer display and controls (play/pause button, orange when running)
  - Edit and delete buttons (disabled when task is completed)
  - Chevron for expanding/collapsing subtasks
  - Formatted time display (HH:MM:SS or MM:SS)
  - Subtask counter badge
  - Rounded background with padding
- **EditTodoSheet**: Modal dialog for editing task details
  - Form-based interface with grouped sections
  - Custom toolbar with Save/Cancel buttons
  - Timestamp display (created, started, completed) - read-only
  - Time estimation picker (hours: 0-23, minutes: 0-59)
  - Due date toggle and picker
  - Text editor for description with scroll support
  - Validation: Save disabled if title is empty
  - Keyboard shortcuts: Cmd+Return (Save), Cmd+. (Cancel)
- **SubtaskRow**: Reusable component for displaying subtasks
  - Compact design with rounded background
  - Completion checkbox
  - Title with strikethrough when complete
  - Optional description display (if not empty)
  - Delete button (disabled when parent task is completed)
- **FloatingTaskWindowView**: The floating timer window
  - Collapsible/expandable design with animation
  - Shows task details and subtasks
  - Notes button for taking task notes
  - Subtask toggle functionality with immediate sync
  - Progress bar (when estimated time is set)
  - Over-time indicator with warning icon
  - Complete task button at bottom
  - Timer updates every second
  - Responds to task updates from main window
  - Local task state with binding to window manager
- **NotesEditorView**: Modal notes editor for taking task notes
  - Full-screen text editor
  - Custom toolbar with Save/Cancel
  - Keyboard shortcuts support
  - Syncs notes back to main app via NotificationCenter
  - Minimum size: 500x400
- **FloatingWindowManager**: Singleton manager for the floating window
  - Creates NSPanel with specific styling (non-activating, floating level)
  - Positions window at bottom-right with padding
  - Manages window lifecycle (open/close)
  - Publishes current task for observers
  - Uses NSHostingView to host SwiftUI content
  - Window configuration: `.floating` level, `.canJoinAllSpaces`, `.fullScreenAuxiliary`

All state is managed using SwiftUI's `@State` property wrapper, keeping the UI reactive and up-to-date. Communication between the main window and floating window uses NotificationCenter for decoupled architecture.

### Technical Implementation Details

#### State Management
- **@State**: Used for local view state (todos, newTodoText, expandedTodos, etc.)
- **@FocusState**: Manages focus for subtask input fields
- **@ObservedObject**: FloatingWindowManager publishes currentTask updates
- **@Binding**: Two-way data binding in edit sheets and notes editor
- **@Environment**: System environment values (dismiss action)

#### Timer Implementation
- **Timer.publish()**: Publishes events every second on the main run loop
- **autoconnect()**: Automatically starts the timer when view appears
- **timerUpdateTrigger**: State variable incremented every second to force UI updates
- **currentTimeSpent**: Computed property that adds running time to accumulated time

#### Window Management
- **NSPanel**: Used for floating window (non-activating panel type)
- **NSHostingView**: Hosts SwiftUI view in AppKit window
- **Window level**: `.floating` keeps window above all others
- **Collection behavior**: `.canJoinAllSpaces` + `.fullScreenAuxiliary` for multi-space support
- **becomesKeyOnlyIfNeeded**: Prevents floating window from stealing focus
- **hidesOnDeactivate**: Set to false to keep window visible

#### Drag and Drop
- **draggable()**: Makes tasks draggable with UUID string
- **dropDestination()**: Defines drop zones for reordering
- **moveTodo()**: Handles the actual reordering and reindexing
- **withAnimation()**: Wraps reordering for smooth spring animation

#### Focus Management
- **FocusState**: Tracks which subtask input has focus by UUID
- **DispatchQueue.main.asyncAfter**: Delays focus to ensure UI updates
- **Auto-refocus**: After adding subtask, input refocuses for rapid entry

#### Performance Optimizations
- **LazyVStack**: Lazy loading for large task lists
- **Computed properties**: Separate incomplete/completed todos on-demand
- **Conditional rendering**: Only renders expanded content when needed
- **ForEach with Identifiable**: Efficient list updates with stable IDs

## API Reference (For Developers)

### Data Models

#### TodoItem
```swift
struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID                          // Unique identifier
    var text: String                      // Task title
    var isCompleted: Bool                 // Completion status
    var index: Int                        // Display order
    var totalTimeSpent: TimeInterval      // Accumulated time in seconds
    var lastStartTime: Date?              // When timer was last started (nil if paused)
    var description: String               // Detailed description
    var dueDate: Date?                    // Optional due date
    var isAdhoc: Bool                     // Adhoc task flag
    var fromWho: String                   // Task source/requester
    var estimatedTime: TimeInterval       // Estimated time in seconds
    var subtasks: [Subtask]               // Array of subtasks
    var createdAt: TimeInterval           // Creation timestamp (epoch)
    var startedAt: TimeInterval?          // First timer start (epoch)
    var completedAt: TimeInterval?        // Completion timestamp (epoch)
    var notes: String                     // Working notes
    
    var isRunning: Bool { ... }           // Computed: is timer running?
    var currentTimeSpent: TimeInterval { ... }  // Computed: total including current run
}
```

#### Subtask
```swift
struct Subtask: Identifiable, Codable, Equatable {
    let id: UUID                          // Unique identifier
    var title: String                     // Subtask title
    var description: String               // Optional description
    var isCompleted: Bool                 // Completion status
}
```

### Storage API

#### TodoStorage
```swift
class TodoStorage {
    // Save all todos to ~/Documents/todos.json
    static func save(todos: [TodoItem])
    
    // Load all todos from ~/Documents/todos.json
    static func load() -> [TodoItem]
}
```

### Window Management

#### FloatingWindowManager
```swift
class FloatingWindowManager: ObservableObject {
    static let shared: FloatingWindowManager
    @Published var currentTask: TodoItem?
    
    // Show floating window for specified task
    func showFloatingWindow(for task: TodoItem)
    
    // Close floating window
    func closeFloatingWindow()
    
    // Update task in floating window
    func updateTask(_ task: TodoItem)
}
```

### Notification Events

#### Notification Names
- `ToggleSubtaskFromFloatingWindow` - Fired when subtask toggled in floating window
  - UserInfo: `taskId: UUID`, `subtaskId: UUID`
- `UpdateNotesFromFloatingWindow` - Fired when notes saved from floating window
  - UserInfo: `taskId: UUID`, `notes: String`
- `CompleteTaskFromFloatingWindow` - Fired when task completed from floating window
  - UserInfo: `taskId: UUID`

### View Components

All views accept specific callbacks and bindings:

#### TodoRow
- Displays a single task with all controls
- Callbacks: `onToggle`, `onDelete`, `onToggleTimer`, `onEdit`, `onToggleExpanded`
- Callbacks for subtasks: `onToggleSubtask`, `onDeleteSubtask`, `onEditSubtask`

#### SubtaskRow
- Displays a single subtask
- Callbacks: `onToggle`, `onDelete`

#### EditTodoSheet
- Modal sheet for editing task details
- Binding: `todo: TodoItem`
- Callback: `onSave`

#### NotesEditorView
- Modal sheet for editing task notes
- Binding: `notes: String`
- Parameter: `taskId: UUID`

## Contributing

This is a personal productivity tool, but contributions are welcome! Areas for potential improvement:

### Potential Features
- [ ] Task categories/tags
- [ ] Search and filter functionality
- [ ] Export to CSV/JSON
- [ ] Import from other todo apps
- [ ] Due date notifications/reminders
- [ ] Recurring tasks
- [ ] Task templates
- [ ] Keyboard shortcuts for common actions
- [ ] Multi-select operations
- [ ] Undo/redo functionality
- [ ] Task priority levels
- [ ] Time reports and analytics
- [ ] Dark/light mode toggle (currently uses system)
- [ ] Customizable themes
- [ ] Cloud sync (iCloud)
- [ ] iOS companion app

### Code Improvements
- [ ] Unit tests for TodoStorage
- [ ] UI tests for main workflows
- [ ] Refactor ContentView (currently 1550 lines)
- [ ] Extract subtask management into separate view
- [ ] Protocol-based architecture for better testing
- [ ] SwiftLint integration
- [ ] Documentation comments (Swift DocC)

## License

This project is available for personal and educational use. See code for specific details.

## Acknowledgments

Built with:
- **SwiftUI** - Apple's declarative UI framework
- **AppKit** - For floating window management (NSPanel)
- **Foundation** - Core functionality and data persistence

### Data Persistence

All task data is automatically saved to `~/Documents/todos.json` in the following format:

```json
{
  "tasks": {
    "task-uuid-1": {
      "title": "Implement new feature",
      "index": 0,
      "isCompleted": false,
      "totalTimeSpent": 3600,
      "description": "Add user authentication to the app",
      "dueDate": 1707696000,
      "isAdhoc": false,
      "fromWho": "Product Manager",
      "estimatedTime": 7200,
      "createdAt": 1707609600,
      "startedAt": 1707610000,
      "notes": "Need to research OAuth 2.0 implementation",
      "subtasks": [
        {
          "id": "subtask-uuid-1",
          "title": "Research authentication methods",
          "description": "",
          "isCompleted": true
        },
        {
          "id": "subtask-uuid-2",
          "title": "Implement login form",
          "description": "",
          "isCompleted": false
        }
      ]
    },
    "task-uuid-2": {
      "title": "Walk the dog",
      "index": 1,
      "isCompleted": true,
      "totalTimeSpent": 1200,
      "description": "",
      "isAdhoc": true,
      "fromWho": "",
      "estimatedTime": 900,
      "createdAt": 1707609700,
      "startedAt": 1707610100,
      "completedAt": 1707611300,
      "notes": "",
      "subtasks": []
    }
  }
}
```

The app automatically:
- Loads all tasks and their data when launched
- Saves after any change (adding, editing, completing, deleting tasks or subtasks)
- Maintains task order using the `index` field
- Preserves all timestamps, time tracking, and metadata
- Stores task notes and subtask information

## Troubleshooting

### Data Not Saving
- **Check file location**: Data is saved to `~/Documents/todos.json`
- **Verify permissions**: Ensure app has write access to Documents folder
- **Check console logs**: Look for "Error saving todos" messages in Console.app

### Floating Window Not Appearing
- **Start a timer**: Floating window only appears when a timer is running
- **Check if hidden**: Window may be on another Space/Desktop
- **Restart app**: Sometimes window state needs reset

### Floating Window Not Staying On Top
- **System Preferences**: Check Mission Control settings for window management
- **Full-screen apps**: Window should appear in full-screen apps (if not, file a bug)

### Timer Not Updating
- **Check if running**: Make sure timer shows orange pause button (not blue play button)
- **Force refresh**: Click pause and play again to restart timer
- **Multiple tasks**: Only one timer can run at a time

### Tasks Disappeared
- **Check completed section**: Completed tasks are in collapsible section at bottom
- **Expand completed**: Click "Completed (N)" header to show completed tasks
- **Check JSON file**: View `~/Documents/todos.json` to see raw data

### App Won't Build
- **Xcode version**: Ensure Xcode 14.0 or later is installed
- **macOS version**: Requires macOS 13.0+ to build and run
- **Clean build**: Try `Product > Clean Build Folder` in Xcode or `make clean`
- **Derived Data**: Delete Xcode's derived data and rebuild

### Performance Issues
- **Large task list**: App uses lazy loading, but thousands of tasks may slow down
- **Reduce completed tasks**: Archive old completed tasks by manually editing JSON file
- **Restart app**: Helps clear any accumulated state

## Tips & Best Practices

### Effective Time Tracking
1. **Start timer when beginning work** - don't forget to play the timer
2. **Use subtasks for detailed tracking** - break down tasks to understand time distribution
3. **Set estimates** - helps identify tasks taking longer than expected
4. **Review timestamps** - use created/started/completed times for productivity analysis
5. **Take notes** - use the notes feature to document blockers, decisions, and learnings

### Task Organization
1. **Use descriptive titles** - make tasks scannable at a glance
2. **Add details in description** - save context for when you return to the task
3. **Set due dates** - helps prioritize (even without notifications)
4. **Mark adhoc tasks** - helps distinguish planned vs. interrupt-driven work
5. **Track "from who"** - useful for team environments to remember task source

### Subtask Usage
1. **Keep subtasks focused** - each should be a discrete action
2. **Use for checklists** - perfect for multi-step procedures
3. **Check off as you go** - provides motivation and tracks progress
4. **Don't over-nest** - subtasks don't have sub-subtasks (keep it flat)

### Workflow Tips
1. **Drag to prioritize** - put urgent tasks at the top
2. **Use floating window** - keeps task visible while working in other apps
3. **Collapse when done** - minimize floating window to reduce distraction
4. **Regular cleanup** - periodically delete or archive old completed tasks
5. **Backup JSON file** - copy `~/Documents/todos.json` for backup
