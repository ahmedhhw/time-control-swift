# TimeControl Test Suite

Comprehensive unit tests for the TimeControl macOS application.

## 📊 Test Statistics

- **Total Test Files:** 5
- **Total Test Cases:** 150+
- **Code Coverage Areas:** Models, Storage, Operations, Time Calculations

## 📁 Test Files

### 1. TodoItemTests.swift (45+ tests)
Tests for the core `TodoItem` model including:
- ✅ Initialization with default and custom parameters
- ✅ Timer functionality (isRunning, currentTimeSpent)
- ✅ Timestamp tracking (createdAt, startedAt, completedAt)
- ✅ Property management (description, dueDate, estimatedTime, notes)
- ✅ Subtask integration
- ✅ Adhoc task flags
- ✅ Equatable conformance

**Key Test Methods:**
- `testTodoItemInitialization()`
- `testIsRunningWhenTimerStarted()`
- `testCurrentTimeSpentWithRunningTimer()`
- `testTimerAccumulatesTime()`
- `testCreatedAtDefaultsToNow()`
- `testAddingSubtasks()`
- `testTodoItemEquality()`

### 2. SubtaskTests.swift (13+ tests)
Tests for the `Subtask` model including:
- ✅ Initialization and default values
- ✅ Property modifications
- ✅ Completion state toggling
- ✅ Identifiable conformance
- ✅ Equatable conformance

**Key Test Methods:**
- `testSubtaskInitialization()`
- `testSubtaskCompletion()`
- `testSubtaskEquality()`
- `testSubtaskHasUniqueId()`

### 3. TodoStorageTests.swift (25+ tests)
Tests for the JSON persistence layer including:
- ✅ Save and load operations
- ✅ Empty and non-existent file handling
- ✅ Order preservation
- ✅ Subtask persistence
- ✅ Timestamp persistence
- ✅ Multiple save/load cycles
- ✅ Data overwriting

**Key Test Methods:**
- `testSaveSingleTodo()`
- `testLoadWhenFileDoesNotExist()`
- `testLoadPreservesOrder()`
- `testSaveAndLoadSubtasks()`
- `testMultipleSaveLoadCycles()`

**Note:** Uses temporary files to avoid affecting production data.

### 4. TodoOperationsTests.swift (30+ tests)
Tests for core application operations including:
- ✅ Adding todos with correct indices
- ✅ Toggling completion status
- ✅ Deleting and reindexing
- ✅ Timer operations (start, stop, multiple sessions)
- ✅ Moving/reordering todos
- ✅ Subtask operations (add, toggle, delete)
- ✅ Filtering (incomplete, completed, running)

**Key Test Methods:**
- `testAddTodoToEmptyList()`
- `testToggleTodoCompletion()`
- `testDeleteAndReindex()`
- `testStartTimer()`
- `testOnlyOneTimerRunningAtOnce()`
- `testMoveTodoInList()`
- `testFilterIncompleteTodos()`

### 5. TimeFormattingTests.swift (37+ tests)
Tests for time calculations and edge cases including:
- ✅ Zero and boundary time values
- ✅ Running timer calculations
- ✅ Estimated time comparisons
- ✅ Progress calculations
- ✅ Date and timestamp edge cases
- ✅ Timer state transitions
- ✅ Concurrent timer scenarios
- ✅ Performance edge cases

**Key Test Methods:**
- `testExactlyOneHour()`
- `testTimerWithPreviousTime()`
- `testProgressFiftyPercent()`
- `testMultipleStartStopCycles()`
- `testOnlyOneTaskShouldHaveRunningTimer()`
- `testSubtaskCompletionPercentage()`

## 🎯 Coverage Areas

### Models
- **TodoItem**: Complete coverage of all properties and computed values
- **Subtask**: Full initialization and state management testing

### Persistence
- **Save Operations**: Single, multiple, and complex todos
- **Load Operations**: Various file states and data structures
- **Data Integrity**: Round-trip save/load validation

### Core Operations
- **CRUD Operations**: Create, Read, Update, Delete
- **Timer Management**: Start, stop, accumulate time
- **List Management**: Reordering, filtering, indexing

### Edge Cases
- **Time Calculations**: Zero, negative, very large values
- **Boundary Conditions**: Empty lists, single items, large datasets
- **Concurrent Operations**: Multiple timers, simultaneous updates

## 🚀 Running the Tests

### In Xcode
1. Open the project: `open TimeControl.xcodeproj`
2. Press `Cmd+U` to run all tests
3. Or use the Test Navigator to run individual test files/methods

### Command Line
```bash
# Run all tests
xcodebuild test -scheme TimeControl -destination 'platform=macOS'

# With verbose output
xcodebuild test -scheme TimeControl -destination 'platform=macOS' | xcpretty

# Run specific test file
xcodebuild test -scheme TimeControl -destination 'platform=macOS' -only-testing:TimeControlTests/TodoItemTests
```

### Using Make (if configured)
```bash
make test
```

## 📝 Test Patterns

### Isolated Tests
Each test is independent and doesn't rely on other tests. Tests clean up after themselves.

### Descriptive Names
Test names clearly describe what is being tested:
- `test[Feature][Condition]()`
- Example: `testTimerAccumulatesTime()`

### AAA Pattern
Tests follow Arrange-Act-Assert pattern:
```swift
func testExample() {
    // Arrange - Set up test data
    var todo = TodoItem(text: "Test")
    
    // Act - Perform the operation
    todo.isCompleted = true
    
    // Assert - Verify the result
    XCTAssertTrue(todo.isCompleted)
}
```

### Temporary Data
Storage tests use temporary files that are cleaned up:
```swift
override func setUp() {
    testStorageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test_\(UUID()).json")
}

override func tearDown() {
    try? FileManager.default.removeItem(at: testStorageURL)
}
```

## 🔍 Assertions Used

- `XCTAssertEqual()` - Value equality
- `XCTAssertNotEqual()` - Value inequality
- `XCTAssertTrue()` / `XCTAssertFalse()` - Boolean conditions
- `XCTAssertNil()` / `XCTAssertNotNil()` - Optional values
- `XCTAssertGreaterThan()` / `XCTAssertLessThan()` - Comparisons
- `XCTAssertEqual(_, accuracy:)` - Floating-point comparisons with tolerance

## 🐛 Debugging Failed Tests

When a test fails:

1. **Check the failure message** - Xcode shows which assertion failed
2. **Review the test name** - Understand what was being tested
3. **Check recent changes** - Did you modify the related code?
4. **Run the test in isolation** - Click the diamond next to the test method
5. **Add breakpoints** - Debug the test execution
6. **Check test data** - Ensure test setup is correct

## 📚 Best Practices

### Writing New Tests
1. Test one thing per test method
2. Use descriptive test names
3. Keep tests simple and readable
4. Don't test framework code, only your logic
5. Use setup/teardown for common initialization

### Maintaining Tests
1. Update tests when requirements change
2. Remove obsolete tests
3. Keep tests fast - avoid long sleeps/delays
4. Mock external dependencies (network, file system where appropriate)

## 🔄 Continuous Integration

These tests are designed to run in CI environments:
- Fast execution (< 5 seconds total)
- No external dependencies
- Deterministic results
- Clean temporary data

Example CI configuration:
```yaml
test:
  script:
    - xcodebuild test -scheme TimeControl -destination 'platform=macOS'
```

## 📈 Future Test Coverage

Potential areas for expansion:
- [ ] UI tests for SwiftUI views
- [ ] Integration tests for NotificationCenter events
- [ ] Performance tests for large todo lists
- [ ] Accessibility tests
- [ ] Localization tests

## 📖 References

- [XCTest Framework Documentation](https://developer.apple.com/documentation/xctest)
- [Testing in Xcode](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)
- [Swift Testing Best Practices](https://developer.apple.com/videos/play/wwdc2018/417/)

---

**Last Updated:** February 11, 2026  
**Test Framework:** XCTest  
**Minimum macOS:** 13.0+
