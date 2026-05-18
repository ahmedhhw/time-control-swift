🎉 Welcome to TimeControl v1.0!

TimeControl is a comprehensive macOS productivity application that combines traditional task management with sophisticated time tracking capabilities. Built entirely with native SwiftUI and AppKit, TimeControl offers a modern, elegant solution for managing your todos and tracking your time with precision.

✨ KEY FEATURES

🪟 Floating Timer Window
• Always-on-Top Display: Timer window stays visible across all macOS Spaces, desktops, and fullscreen applications
• Collapsible Design: Minimize to 50px or expand to full view with smooth animated transitions
• Task Context at a Glance: View task name, description, subtasks, and progress without switching windows
• Interactive Controls: Complete subtasks, take notes, and finish tasks directly from the floating window
• Smart Positioning: Automatically positioned at bottom-right with 20px padding, fully resizable and movable

⏱️ Advanced Time Tracking
• Precise Tracking: Accumulate time spent on each task with play/pause controls that update every second
• Single-Task Focus: Only one task timer can run at a time - starting a new timer automatically pauses others
• Countdown Timer Mode: Set countdown timers for tasks with visual countdown and alerts when time expires
• Smart Auto-Pause: Timer automatically stops when marking a task complete
• Detailed Timestamps: Track when tasks were created, started (first play), and completed
• Progress Visualization: Compare actual time vs. estimated time with visual progress bars
• Over-Time Warnings: Visual indicators when tasks exceed their estimated time

📋 Comprehensive Task Management
• Unlimited Hierarchical Subtasks: Break down tasks into manageable subtasks with independent completion tracking
• Rich Task Details: Add descriptions, notes, due dates, time estimates, and metadata to every task
• Drag-and-Drop Reordering: Intuitive task organization with smooth animations
• Advanced Filtering: Filter by completion status, task text, description, and metadata
• Multiple Sorting Options: Sort by creation date, completion time, time spent, due date, and more
• Mass Operations: Select multiple tasks for bulk delete, complete, or export operations
• Export Functionality: Export tasks to JSON or CSV for external analysis

🎯 User Experience Features
• Advanced Mode: Toggle detailed view to see progress bars, due dates, and time estimates inline
• Smart Tooltips: Hover over tasks to see full details in an extended tooltip window
• Collapsible Sections: Keep your workspace clean with collapsible completed tasks section
• Confirmation Dialogs: Protect against accidental deletions with confirmation prompts
• Native macOS Integration: Full support for light/dark mode with native system styling
• Auto-Save: All changes immediately persist to JSON storage - no manual save needed
• Keyboard Shortcuts: Efficient workflows with Cmd+Return to save, Cmd+. to cancel

📊 Productivity Insights
• Stay on Track Reminders: Optional alerts when switching away from a task with running timer
• Adhoc Task Tracking: Flag unexpected tasks to understand interrupt-driven work
• Task Attribution: Track who assigned or requested each task
• Comprehensive Notes: Take detailed notes while working, accessible from floating window
• Time Analytics: Review created/started/completed timestamps for productivity analysis

🎨 Polish & Details
• Smooth Animations: Spring-based animations for expand/collapse and reordering operations
• Visual Feedback: Running timers display in blue, paused timers in secondary color
• Monospaced Time Display: Consistent, easy-to-read time formatting (HH:MM:SS or MM:SS)
• Responsive Layout: Minimum window size 400x300, fully resizable to your preference
• Context-Aware Controls: Buttons and fields adapt based on task state
• Empty State Messaging: Helpful guidance when starting fresh
• Window Memory: Floating window position persists across app launches

🔧 TECHNICAL HIGHLIGHTS

• Pure SwiftUI: Modern declarative UI built entirely with SwiftUI
• Native Performance: Zero external dependencies, leveraging Foundation and AppKit
• JSON Persistence: All data automatically saved to ~/Documents/todos.json
• NotificationCenter Sync: Real-time communication between main and floating windows
• Lazy Loading: Efficient rendering for large task lists
• macOS 13.0+: Requires macOS Ventura or later

📦 INSTALLATION

Option 1: Build from Source
cd TimeControl
xcodebuild -project TimeControl.xcodeproj -scheme TimeControl -configuration Release
open ~/Library/Developer/Xcode/DerivedData/TimeControl-*/Build/Products/Release/TimeControl.app

Option 2: Create DMG for Distribution
cd TimeControl
make dmg # Create styled DMG
make install # Build DMG and open for installation

DMG files are created in the dist/ directory.

Option 3: Download and install TimeControl.dmg that is attached to this release
There will be .dmg files attached to this release. Please download and install the app through them then run the command below before you run your app to remove the notarization notice:
xattr -dr com.apple.quarantine /Applications/TimeControl.app

🚀 GETTING STARTED

Add Your First Task: Type in the text field at the top and press Enter
Start Tracking Time: Click the play button (▶️) to start the timer
Use the Floating Window: Timer opens automatically - stays visible across all apps
Break Down Tasks: Click the chevron to expand and add subtasks
Add Details: Click the pencil icon to set estimates, due dates, and descriptions
Stay Organized: Drag tasks to reorder, use filters to find what you need
📖 WHAT'S INCLUDED IN THIS RELEASE

Core Features (66 Commits)
✅ Task creation, editing, deletion with comprehensive metadata
✅ Hierarchical subtask management with unlimited depth
✅ Precise time tracking with play/pause controls
✅ Countdown timer mode with completion alerts
✅ Floating window that stays on top across all Spaces
✅ Real-time sync between main window and floating window
✅ Collapsible/expandable floating window design
✅ Advanced filtering and sorting capabilities
✅ Mass operations (select multiple, bulk actions)
✅ Export to JSON and CSV formats
✅ Advanced mode with inline progress visualization
✅ Stay on track reminders and attention alerts
✅ Notes editor for task documentation
✅ Comprehensive timestamp tracking
✅ Auto-save to JSON with instant persistence
✅ Native macOS UI with light/dark mode support
✅ Drag-and-drop task reordering
✅ Delete confirmation dialogs
✅ Tooltip windows for extended information
✅ User settings for customization

Quality Assurance
✅ Comprehensive test suite with 5 test files
✅ TodoItemTests: Model validation and behavior tests
✅ TodoStorageTests: Persistence and data integrity tests
✅ TodoOperationsTests: Task manipulation and workflow tests
✅ TimeFormattingTests: Time display and formatting tests
✅ SubtaskTests: Hierarchical task management tests

Documentation
✅ Comprehensive README with 790+ lines of documentation
✅ DMG creation guide with detailed instructions
✅ Quick reference guide for common tasks
✅ Test suite documentation
✅ Script documentation for automation

Build & Distribution
✅ Makefile with convenient build targets
✅ DMG creation scripts with Finder styling
✅ Custom app icon in all required sizes
✅ Proper app entitlements configuration

🎯 USE CASES

Perfect for:
• Software developers tracking time on tasks and bugs
• Freelancers billing clients by the hour
• Project managers monitoring task completion
• Students managing assignments and study time
• Anyone wanting to understand where their time goes

Workflow Examples:
• Focus Sessions: Start timer, collapse floating window, work distraction-free
• Task Breakdown: Create task, add subtasks, estimate time, track progress
• Client Work: Track "from who", set estimates, export time logs for billing
• Interrupt Analysis: Mark adhoc tasks to see how much time goes to interruptions
• Review & Reflect: Sort by completion time, review timestamps, analyze patterns

🔒 LICENSE & PHILOSOPHY

TimeControl is licensed under GNU AGPL-3.0, a strong copyleft license that ensures:
✅ Free to use, modify, and distribute
✅ Can be used commercially
⚠️ Any modifications must be shared under the same license
⚠️ Derivative works must remain open source
🔒 Prevents proprietary forks without contributing back

This viral license protects the open source nature of TimeControl and ensures the community benefits from all improvements.

🚫 KNOWN LIMITATIONS (BY DESIGN)

Some limitations are intentional design decisions:
• Single Timer: Only one task timer can run at a time (enforces focus)
• Read-Only Completed Tasks: Edit/timer/delete disabled for completed tasks (prevents accidents)
• No Subtask Editing: Subtasks are delete-and-recreate only (simplified workflow)
• Local Storage Only: No cloud sync - all data stored in ~/Documents/todos.json
• No Recurring Tasks: Each task is unique, no repeat scheduling
• No Due Date Notifications: Set due dates for reference, but no alerts

📊 PROJECT STATISTICS

• Total Commits: 66
• Lines of Code: 10,790+ insertions
• Main Source File: 4,264 lines (ContentView.swift)
• Test Coverage: 5 comprehensive test suites
• Documentation: 790+ line README
• Development Time: Built from February 11-15, 2026

🙏 ACKNOWLEDGMENTS

Built with:
• SwiftUI - Apple's declarative UI framework
• AppKit - For advanced window management (NSPanel)
• Foundation - Core functionality and JSON persistence
• AVFoundation - Audio alerts for countdown completion

🔮 FUTURE POSSIBILITIES

While v1.0 is feature-complete, potential future enhancements include:
• Task categories and tags
• Search and advanced filtering
• Due date notifications and reminders
• Recurring task templates
• Time reports and analytics dashboard
• iCloud sync
• iOS companion app
• Custom keyboard shortcuts
• Undo/redo functionality
• Task priority levels

📞 SUPPORT & CONTRIBUTING

• Issues: Report bugs or request features via GitHub Issues
• Documentation: Full documentation in README.md
• Contributing: PRs welcome! See README for areas of improvement
• License: All contributions must be under AGPL-3.0

🎊 Thank You!

Thank you for trying TimeControl v1.0! This release represents a complete, production-ready task management and time tracking solution for macOS. Whether you're tracking billable hours, managing projects, or simply trying to understand where your time goes, TimeControl provides the tools you need.

Built with ❤️ using SwiftUI

For detailed usage instructions, troubleshooting, and API documentation, see the comprehensive README.md file.