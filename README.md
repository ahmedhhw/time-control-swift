# TodoApp - macOS Todo List with Time Tracking

A comprehensive macOS todo list application built with SwiftUI, featuring time tracking, task management, and productivity tools.

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
- 🪟 **Floating window** - timer opens a small floating window that stays on top of all applications
- 🎯 Floating window features:
  - Always visible across all spaces/desktops
  - Shows current task name, description, and subtasks
  - Collapsible/expandable design
  - Check off subtasks directly from the floating window
  - Take notes while working on the task

### Subtasks
- 📋 Add unlimited subtasks to any task
- ✅ Mark subtasks as complete/incomplete
- 🗑️ Delete individual subtasks
- 🔽 Expandable/collapsible subtask view with chevron indicator
- 🎯 Quick subtask entry with auto-focus for rapid task breakdown
- 📝 Subtask counter badge showing number of subtasks
- 🔄 Subtasks sync between main window and floating window

### Task Details & Metadata
- 📝 **Task title and description** - add detailed context to tasks
- 📅 **Due date and time** - set deadlines with calendar picker
- ⚡ **Adhoc task flag** - mark tasks that came up unexpectedly
- 👤 **"From who" field** - track who assigned or requested the task
- ⏳ **Estimated time** - set time estimates in hours and minutes
- 📓 **Task notes** - take detailed notes while working on a task (accessible from floating window)

### Timestamps & Analytics
- 🕐 **Created timestamp** - when the task was created
- ▶️ **Started timestamp** - when the timer was first started
- ✅ **Completed timestamp** - when the task was marked complete
- 📊 All timestamps displayed in readable format (date and time)

### UI/UX Features
- 💾 **Persistent storage** - all data automatically saved to JSON and restored on app launch
- 🎨 Modern macOS UI with native styling
- 🌓 Respects system light/dark mode
- ⚡ Real-time UI updates for running timers
- 🎯 Focused input experience with automatic text field management
- 🔔 Visual indicators for running timers (blue color)
- 🚫 Automatic timer pause when task is completed
- 🎭 Smooth animations for expand/collapse and reordering

## How to Run

### Option 1: Using Xcode (GUI)

1. Open `TodoApp/TodoApp.xcodeproj` in Xcode
2. Make sure the target is set to "My Mac" or your Mac device
3. Press `Cmd + R` to build and run the app

Alternatively, you can open the project from Finder by double-clicking the `TodoApp.xcodeproj` file.

### Option 2: Using Command Line (without Xcode IDE)

**Prerequisites**: Xcode Command Line Tools must be installed:
```bash
xcode-select --install
```

**Build and run the app:**

```bash
cd TodoApp
xcodebuild -project TodoApp.xcodeproj -scheme TodoApp -configuration Debug
open ~/Library/Developer/Xcode/DerivedData/TodoApp-*/Build/Products/Debug/TodoApp.app
```

**Or build a release version:**

```bash
cd TodoApp
xcodebuild -project TodoApp.xcodeproj -scheme TodoApp -configuration Release
open ~/Library/Developer/Xcode/DerivedData/TodoApp-*/Build/Products/Release/TodoApp.app
```

**One-liner to build and run:**

```bash
cd TodoApp && xcodebuild -project TodoApp.xcodeproj -scheme TodoApp -configuration Debug && open ~/Library/Developer/Xcode/DerivedData/TodoApp-*/Build/Products/Debug/TodoApp.app
```

## Build a DMG (Distribution)

### Quick Start with Make

The easiest way to create a DMG is using the Makefile:

```bash
cd TodoApp
make dmg              # Create styled DMG
make dmg-quick        # Create DMG without styling (faster)
make dmg-version VERSION=1.0.0  # Create versioned DMG
make release          # Clean build + create DMG
```

### Using the Script Directly

You can also use the build script directly with more options:

```bash
cd TodoApp
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
- Default: `dist/TodoApp.dmg`
- Versioned: `dist/TodoApp-1.0.0.dmg`

For more details, see `TodoApp/scripts/README.md`

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later

## Usage

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
- **Take notes**: Click the "Notes" button to open the notes editor
- **Check subtasks**: Toggle subtask completion directly from the floating window
- **Collapse/expand**: Click the chevron at the top to minimize/maximize
- **Always on top**: Stays visible across all applications and desktops

### Task Details
- **Edit task details**: Click the pencil icon to open the edit sheet where you can:
  - Change the task title
  - Add/edit description
  - Set estimated time (hours and minutes)
  - Set due date and time
  - Mark as adhoc task
  - Add "from who" information
  - View created, started, and completed timestamps

### Organization
- **Reorder tasks**: Drag and drop tasks to change their order
- **View completed**: Click the "Completed" section header to expand/collapse completed tasks
- **Completed tasks** are automatically moved to a separate collapsible section at the bottom

## Project Structure

```
TodoApp/
├── TodoApp.xcodeproj/          # Xcode project file
├── TodoApp/
│   ├── TodoAppApp.swift        # Main app entry point
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
│   ├── TodoApp.entitlements    # App permissions
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
- **TodoStorage**: Handles JSON persistence to `~/Documents/todos.json`
  - Saves all task data including subtasks, timestamps, and metadata
  - Loads and restores tasks on app launch
  - Maintains task order using index field

### Views
- **ContentView**: The main view with:
  - Task list management (incomplete and completed sections)
  - Timer management and UI updates
  - Drag and drop reordering
  - Notification handling for floating window communication
- **TodoRow**: Displays individual tasks with:
  - Completion toggle
  - Timer display and controls
  - Edit and delete buttons
  - Chevron for expanding/collapsing subtasks
- **EditTodoSheet**: Modal dialog for editing task details
  - Form-based interface for all task properties
  - Timestamp display (created, started, completed)
  - Time estimation picker
- **SubtaskRow**: Reusable component for displaying subtasks
- **FloatingTaskWindowView**: The floating timer window
  - Collapsible/expandable design
  - Shows task details and subtasks
  - Notes button for taking task notes
  - Subtask toggle functionality
- **NotesEditorView**: Modal notes editor for taking task notes
- **FloatingWindowManager**: Singleton manager for the floating window
  - Creates and positions the floating window
  - Manages window lifecycle
  - Handles task updates

All state is managed using SwiftUI's `@State` property wrapper, keeping the UI reactive and up-to-date. Communication between the main window and floating window uses NotificationCenter.

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
