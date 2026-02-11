# TodoApp - Simple macOS Todo List

A clean and simple macOS todo list application built with SwiftUI.

## Features

- ✨ Add todo items via a text field at the top
- ✅ Mark todos as complete/incomplete with a checkbox
- 📜 Scrollable list view for all your todos
- 🗑️ Delete todos with a trash button
- 🎨 Modern macOS UI with native styling

## How to Run

1. Open `TodoApp/TodoApp.xcodeproj` in Xcode
2. Make sure the target is set to "My Mac" or your Mac device
3. Press `Cmd + R` to build and run the app

Alternatively, you can open the project from Finder by double-clicking the `TodoApp.xcodeproj` file.

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

- **TodoItem**: A struct representing a single todo with an ID, text, and completion status
- **ContentView**: The main view containing the text field and scrollable todo list
- **TodoRow**: A reusable component for displaying individual todo items

All state is managed using SwiftUI's `@State` property wrapper, keeping the UI reactive and up-to-date.
