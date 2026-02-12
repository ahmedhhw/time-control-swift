#!/bin/bash

# Script to set up unit tests for TodoApp
# This script helps verify test files and provides guidance

set -e

echo "======================================"
echo "TodoApp Unit Test Setup"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -d "TodoApp.xcodeproj" ]; then
    echo "❌ Error: TodoApp.xcodeproj not found"
    echo "Please run this script from the TodoApp directory"
    exit 1
fi

echo "✅ Found TodoApp.xcodeproj"

# Check if test files exist
TEST_FILES=(
    "TodoAppTests/TodoItemTests.swift"
    "TodoAppTests/SubtaskTests.swift"
    "TodoAppTests/TodoStorageTests.swift"
    "TodoAppTests/TodoOperationsTests.swift"
    "TodoAppTests/TimeFormattingTests.swift"
)

echo ""
echo "Checking test files..."
MISSING_FILES=0
for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (missing)"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo "❌ Some test files are missing!"
    exit 1
fi

echo ""
echo "✅ All test files found!"
echo ""
echo "======================================"
echo "Next Steps:"
echo "======================================"
echo ""
echo "1. Open the project in Xcode:"
echo "   open TodoApp.xcodeproj"
echo ""
echo "2. Add a test target if you don't have one:"
echo "   File → New → Target → Unit Testing Bundle"
echo "   Name: TodoAppTests"
echo ""
echo "3. Add test files to the project:"
echo "   - Right-click TodoAppTests folder"
echo "   - Add Files to TodoApp..."
echo "   - Select all 4 test files in TodoAppTests/"
echo "   - Make sure 'TodoAppTests' target is checked"
echo ""
echo "4. Run the tests:"
echo "   Press Cmd+U or Product → Test"
echo ""
echo "Or try running from command line:"
echo "   xcodebuild test -scheme TodoApp -destination 'platform=macOS'"
echo ""
echo "======================================"
echo "Test Coverage Summary:"
echo "======================================"
echo ""
echo "📊 Total: 150+ unit tests"
echo ""
echo "Test Files:"
echo "  • TodoItemTests.swift       - 45+ tests"
echo "  • SubtaskTests.swift        - 13+ tests"
echo "  • TodoStorageTests.swift    - 25+ tests"
echo "  • TodoOperationsTests.swift - 30+ tests"
echo "  • TimeFormattingTests.swift - 37+ tests"
echo ""
echo "Coverage Areas:"
echo "  ✅ Model initialization"
echo "  ✅ Timer functionality"
echo "  ✅ Data persistence"
echo "  ✅ Todo operations (add, delete, toggle)"
echo "  ✅ Subtask management"
echo "  ✅ Timestamp tracking"
echo "  ✅ Filtering and sorting"
echo ""
echo "See ADD_TESTS_TO_PROJECT.md for detailed instructions"
echo ""
