#!/bin/bash

# Script to configure and run TodoApp tests
# This script opens Xcode and provides instructions for setting up the test target

set -e

echo "======================================"
echo "TodoApp Test Configuration"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -d "TodoApp.xcodeproj" ]; then
    echo "❌ Error: TodoApp.xcodeproj not found"
    echo "Please run this script from the TodoApp directory"
    exit 1
fi

echo "✅ Found TodoApp.xcodeproj"
echo ""

# Check if test files exist
TEST_FILES=(
    "TodoAppTests/CompilationTest.swift"
    "TodoAppTests/TodoItemTests.swift"
    "TodoAppTests/SubtaskTests.swift"
    "TodoAppTests/TodoStorageTests.swift"
    "TodoAppTests/TodoOperationsTests.swift"
    "TodoAppTests/TimeFormattingTests.swift"
)

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
echo ""

if [ $MISSING_FILES -gt 0 ]; then
    echo "❌ Some test files are missing!"
    exit 1
fi

echo "✅ All test files found!"
echo ""

# Check if test target exists in project
if grep -q "TodoAppTests" TodoApp.xcodeproj/project.pbxproj; then
    echo "✅ Test target found in project"
    echo ""
    echo "Running tests..."
    echo ""
    
    # Try to run tests
    xcodebuild test -scheme TodoApp -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite|Test Case|passed|failed|error:)" || {
        echo ""
        echo "⚠️  Tests couldn't run automatically"
        echo ""
        echo "Please try running tests manually in Xcode:"
        echo "1. Open TodoApp.xcodeproj"
        echo "2. Press Cmd+U to run tests"
    }
else
    echo "⚠️  Test target not found in project"
    echo ""
    echo "======================================"
    echo "Quick Setup Instructions:"
    echo "======================================"
    echo ""
    echo "The test files are ready, but they need to be added to the Xcode project."
    echo ""
    echo "📋 COPY THESE STEPS:"
    echo ""
    echo "1. Open the project:"
    echo "   open TodoApp.xcodeproj"
    echo ""
    echo "2. In Xcode, add a test target:"
    echo "   • File → New → Target"
    echo "   • Select 'Unit Testing Bundle' (under macOS)"
    echo "   • Name: TodoAppTests"
    echo "   • Target to be tested: TodoApp"
    echo "   • Click 'Finish'"
    echo ""
    echo "3. Add the test files:"
    echo "   • Right-click 'TodoAppTests' folder in Project Navigator"
    echo "   • Select 'Add Files to \"TodoApp\"...'"
    echo "   • Navigate to TodoAppTests folder"
    echo "   • Select all .swift files"
    echo "   • Make sure 'TodoAppTests' target is checked"
    echo "   • Click 'Add'"
    echo ""
    echo "4. Delete the auto-generated test file (if exists):"
    echo "   • Delete 'TodoAppTests.swift' if it was created"
    echo ""
    echo "5. Run the tests:"
    echo "   • Press Cmd+U"
    echo "   • Or Product → Test"
    echo ""
    echo "======================================"
    echo ""
    echo "Would you like to open Xcode now? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Opening Xcode..."
        open TodoApp.xcodeproj
        echo ""
        echo "✅ Xcode opened! Follow the steps above to add the test target."
    else
        echo ""
        echo "You can open it later with: open TodoApp.xcodeproj"
    fi
fi

echo ""
echo "======================================"
echo "Test Files Summary:"
echo "======================================"
echo ""
echo "📊 6 test files with 150+ unit tests:"
echo ""
echo "  • CompilationTest.swift        - Basic compilation verification"
echo "  • TodoItemTests.swift          - 45+ tests for TodoItem model"
echo "  • SubtaskTests.swift           - 13+ tests for Subtask model"
echo "  • TodoStorageTests.swift       - 25+ tests for persistence"
echo "  • TodoOperationsTests.swift    - 30+ tests for operations"
echo "  • TimeFormattingTests.swift    - 37+ tests for time handling"
echo ""
echo "For more details, see:"
echo "  • ADD_TESTS_TO_PROJECT.md"
echo "  • TEST_SUITE_SUMMARY.md"
echo "  • TodoAppTests/README.md"
echo ""
