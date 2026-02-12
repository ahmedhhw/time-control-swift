# TodoApp - Simple macOS Todo List

A clean and simple macOS todo list application built with SwiftUI.

## Features

- ✨ Add todo items via a text field at the top
- ✅ Mark todos as complete/incomplete with a checkbox
- 📜 Scrollable list view for all your todos
- 🗑️ Delete todos with a trash button
- 💾 **Persistent storage** - todos are automatically saved to JSON and restored on app launch
- 🎨 Modern macOS UI with native styling

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

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later

## Usage

- **Add a todo**: Type in the text field at the top and press Enter or click the + button
- **Mark as complete**: Click the circle icon next to a todo item
- **Delete a todo**: Click the trash icon on the right side of a todo item

## Project Structure

```
TodoApp/
├── TodoApp.xcodeproj/          # Xcode project file
└── TodoApp/
    ├── TodoAppApp.swift        # Main app entry point
    ├── ContentView.swift       # Main UI with todo list logic
    ├── TodoApp.entitlements    # App permissions
    ├── Assets.xcassets/        # App icons and colors
    └── Preview Content/        # SwiftUI preview assets
```

## Code Overview

The app uses SwiftUI and consists of:

- **TodoItem**: A struct representing a single todo with an ID, text, completion status, and index for ordering
- **TodoStorage**: A storage manager that handles JSON persistence of todos to the Documents directory
- **ContentView**: The main view containing the text field and scrollable todo list
- **TodoRow**: A reusable component for displaying individual todo items

All state is managed using SwiftUI's `@State` property wrapper, keeping the UI reactive and up-to-date.

### Data Persistence

Todos are automatically saved to `~/Documents/todos.json` in the following format:

```json
{
  "tasks": {
    "task-uuid-1": {
      "title": "Buy groceries",
      "index": 0,
      "isCompleted": false
    },
    "task-uuid-2": {
      "title": "Walk the dog",
      "index": 1,
      "isCompleted": true
    }
  }
}
```

The app automatically:
- Loads todos when launched
- Saves after adding, completing, or deleting todos
- Maintains task order using the `index` field
