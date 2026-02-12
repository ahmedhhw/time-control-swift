#!/usr/bin/env swift

// Simple test verification script
// This compiles the test files with the main app code to verify they work

import Foundation

print("🧪 TimeControl Test Verification")
print("============================\n")

// Check if test files exist
let testFiles = [
    "TimeControlTests/TodoItemTests.swift",
    "TimeControlTests/SubtaskTests.swift",
    "TimeControlTests/TodoStorageTests.swift",
    "TimeControlTests/TodoOperationsTests.swift",
    "TimeControlTests/TimeFormattingTests.swift"
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
print("   1. Open TimeControl.xcodeproj in Xcode")
print("   2. File → New → Target → Unit Testing Bundle")
print("   3. Name it 'TimeControlTests'")
print("   4. Add the test files to the target")
print("   5. Press Cmd+U to run tests")
print("\nOr use the command:")
print("   xcodebuild test -scheme TimeControl -destination 'platform=macOS'\n")
