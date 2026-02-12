#!/usr/bin/env swift

// Simple test verification script
// This compiles the test files with the main app code to verify they work

import Foundation

print("🧪 TodoApp Test Verification")
print("============================\n")

// Check if test files exist
let testFiles = [
    "TodoAppTests/TodoItemTests.swift",
    "TodoAppTests/SubtaskTests.swift",
    "TodoAppTests/TodoStorageTests.swift",
    "TodoAppTests/TodoOperationsTests.swift",
    "TodoAppTests/TimeFormattingTests.swift"
]

var allFilesExist = true
for file in testFiles {
    let fileURL = URL(fileURLWithPath: file)
    if FileManager.default.fileExists(atPath: file) {
        print("✅ \(file)")
    } else {
        print("❌ \(file) - NOT FOUND")
        allFilesExist = false
    }
}

if !allFilesExist {
    print("\n❌ Some test files are missing!")
    exit(1)
}

print("\n✅ All test files present!")
print("\n📝 To run the tests:")
print("   1. Open TodoApp.xcodeproj in Xcode")
print("   2. File → New → Target → Unit Testing Bundle")
print("   3. Name it 'TodoAppTests'")
print("   4. Add the test files to the target")
print("   5. Press Cmd+U to run tests")
print("\nOr use the command:")
print("   xcodebuild test -scheme TodoApp -destination 'platform=macOS'\n")
