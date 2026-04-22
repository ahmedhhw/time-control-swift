//
//  TodoViewModelTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TodoViewModelTests: XCTestCase {

    // MARK: - Task lifecycle

    func testAddTodo_appendsToTodos() {
        let (vm, _, _) = makeViewModel()
        vm.newTodoText = "Write report"
        vm.addTodo()
        XCTAssertEqual(vm.todos.count, 1)
        XCTAssertEqual(vm.todos[0].text, "Write report")
        XCTAssertTrue(vm.newTodoText.isEmpty)
    }

    func testAddTodo_emptyText_doesNotAdd() {
        let (vm, _, _) = makeViewModel()
        vm.newTodoText = "   "
        vm.addTodo()
        XCTAssertTrue(vm.todos.isEmpty)
    }

    func testToggleTodo_completesTask_andStopsTimer() {
        let (vm, _, _) = makeViewModel()
        vm.newTodoText = "Task"
        vm.addTodo()
        vm.toggleTimer(vm.todos[0])
        vm.toggleTodo(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isCompleted)
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNotNil(vm.todos[0].completedAt)
    }

    func testDeleteTodo_removesFromList() {
        let (vm, _, _) = makeViewModel()
        vm.confirmTaskDeletion = false
        vm.todos = [makeTodo(text: "Task")]
        let todo = vm.todos[0]
        vm.deleteTodo(todo)
        XCTAssertTrue(vm.todos.isEmpty)
    }

    // MARK: - Timer — single task enforcement

    func testToggleTimer_onlyOneTaskRunsAtATime() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]

        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)
        XCTAssertFalse(vm.todos[1].isRunning)

        vm.toggleTimer(vm.todos[1])
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertTrue(vm.todos[1].isRunning)
    }

    func testToggleTimer_pause_stopsTimer() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        vm.toggleTimer(vm.todos[0])
        vm.toggleTimer(vm.todos[0]) // pause
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNil(vm.runningTaskId)
    }

    func testToggleTimer_setsStartedAt_onFirstStart() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        XCTAssertNil(vm.todos[0].startedAt)
        vm.toggleTimer(vm.todos[0])
        XCTAssertNotNil(vm.todos[0].startedAt)
    }

    func testToggleTimer_doesNotOverwriteStartedAt_onResume() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        vm.toggleTimer(vm.todos[0])
        let firstStart = vm.todos[0].startedAt
        vm.toggleTimer(vm.todos[0]) // pause
        vm.toggleTimer(vm.todos[0]) // resume
        XCTAssertEqual(vm.todos[0].startedAt, firstStart)
    }

    // MARK: - Subtask auto-start

    func testToggleSubtask_completing_autoStartsNextIncomplete() {
        let (vm, _, _) = makeViewModel()
        let sub1 = makeSubtask(title: "First")
        let sub2 = makeSubtask(title: "Second")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

        vm.toggleTimer(vm.todos[0])
        // auto-start moves the first incomplete subtask (sub1) to the top and starts it
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtask(runningSub, in: vm.todos[0])

        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub2.id })!.isRunning)
    }

    func testToggleSubtask_completing_pausesItsTimer() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.toggleTimer(vm.todos[0])
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        XCTAssertTrue(runningSub.isRunning)

        vm.toggleSubtask(runningSub, in: vm.todos[0])
        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isRunning)
    }

    func testToggleSubtaskTimer_requiresParentRunning() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        // parent NOT started
        vm.toggleSubtaskTimer(sub, in: vm.todos[0])
        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func testToggleSubtaskTimer_onlyOneSubtaskRunsAtATime() {
        let (vm, _, _) = makeViewModel()
        let sub1 = makeSubtask(title: "A")
        let sub2 = makeSubtask(title: "B")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

        vm.toggleTimer(vm.todos[0])         // sub1 auto-starts
        vm.toggleSubtaskTimer(sub2, in: vm.todos[0])  // stops sub1, starts sub2

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub1.id })!.isRunning)
        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub2.id })!.isRunning)
    }

    // MARK: - Subtask ordering

    func testCompletedSubtasks_movedToTopOfCompletedBlock() {
        let (vm, _, _) = makeViewModel()
        let subA = makeSubtask(title: "A")
        let subB = makeSubtask(title: "B")
        let subC = makeSubtask(title: "C")
        vm.todos = [makeTodo(text: "Parent", subtasks: [subA, subB, subC])]

        vm.toggleTimer(vm.todos[0]) // auto-starts first incomplete
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtask(runningSub, in: vm.todos[0])

        // Completed subtask should be at index 0 (before all incomplete ones)
        XCTAssertTrue(vm.todos[0].subtasks[0].isCompleted)
        XCTAssertFalse(vm.todos[0].subtasks[1].isCompleted)
        XCTAssertFalse(vm.todos[0].subtasks[2].isCompleted)
    }

    func testStartedSubtasks_movedToTopOfIncompleteList() {
        let (vm, _, _) = makeViewModel()
        let subA = makeSubtask(title: "A")
        let subB = makeSubtask(title: "B")
        let subC = makeSubtask(title: "C")
        vm.todos = [makeTodo(text: "Parent", subtasks: [subA, subB, subC])]

        vm.toggleTimer(vm.todos[0])                         // auto-starts subA (already at top)
        vm.toggleSubtaskTimer(subC, in: vm.todos[0])        // stops subA, starts subC → moves subC to top

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "C") // subC is now first
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)
    }

    // MARK: - switchToTask

    func testSwitchToTask_stopsCurrentTask() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        vm.switchToTask(vm.todos[1])
        XCTAssertFalse(vm.todos[0].isRunning)
    }

    func testSwitchToTask_autoPlays_whenSettingEnabled() {
        let (vm, _, _) = makeViewModel()
        vm.autoPlayAfterSwitching = true
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        vm.switchToTask(vm.todos[1])
        XCTAssertTrue(vm.todos[1].isRunning)
    }

    func testSwitchToTask_doesNotAutoPlay_whenSettingDisabled() {
        let (vm, _, _) = makeViewModel()
        vm.autoPlayAfterSwitching = false
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        vm.switchToTask(vm.todos[1])
        XCTAssertFalse(vm.todos[1].isRunning)
    }

    // MARK: - Persistence round-trip

    func testSaveTodos_persistsAndLoadsCorrectly() {
        let (vm, url, dbURL) = makeViewModel()
        vm.newTodoText = "Persisted task"
        vm.addTodo()
        vm.sqliteStorage?.drainWrites()

        let vm2 = TodoViewModel(storageURL: url, dbURL: dbURL)
        XCTAssertEqual(vm2.todos.count, 1)
        XCTAssertEqual(vm2.todos[0].text, "Persisted task")
    }

    // MARK: - Field updates

    func testUpdateTaskFields_updatesTitleAndNotes() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Old")]
        let id = vm.todos[0].id
        vm.updateTaskFields(id: id, text: "New", description: nil, notes: "my note",
                            dueDate: nil, isAdhoc: nil, fromWho: nil, estimatedTime: nil)
        XCTAssertEqual(vm.todos[0].text, "New")
        XCTAssertEqual(vm.todos[0].notes, "my note")
    }

    // MARK: - Countdown

    func testSetCountdown_storesCountdownTime() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let id = vm.todos[0].id
        vm.setCountdown(taskId: id, time: 300)
        XCTAssertEqual(vm.todos[0].countdownTime, 300)
        XCTAssertNotNil(vm.todos[0].countdownStartTime)
    }

    func testClearCountdown_removesCountdownTime() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let id = vm.todos[0].id
        vm.setCountdown(taskId: id, time: 300)
        vm.clearCountdown(taskId: id)
        XCTAssertEqual(vm.todos[0].countdownTime, 0)
        XCTAssertNil(vm.todos[0].countdownStartTime)
    }

    // MARK: - Reordering

    func testMoveTodo_updatesIndexOrder() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [
            TodoItem(text: "A", index: 0),
            TodoItem(text: "B", index: 1),
            TodoItem(text: "C", index: 2)
        ]
        vm.moveTodo(from: 0, to: 2)
        XCTAssertEqual(vm.todos[0].text, "B")
        XCTAssertEqual(vm.todos[1].text, "C")
        XCTAssertEqual(vm.todos[2].text, "A")
        XCTAssertEqual(vm.todos[0].index, 0)
        XCTAssertEqual(vm.todos[1].index, 1)
        XCTAssertEqual(vm.todos[2].index, 2)
    }

    // MARK: - pauseTask / resumeTask

    func testPauseTask_stopsTimer_andClearsRunningTaskId() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)
        XCTAssertNotNil(vm.runningTaskId)

        vm.pauseTask(vm.todos[0].id, keepWindowOpen: false)

        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNil(vm.todos[0].lastStartTime)
        XCTAssertNil(vm.runningTaskId)
    }

    func testPauseTask_keepWindowOpen_doesNotClearRunningTaskId() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id

        vm.pauseTask(taskId, keepWindowOpen: true)

        XCTAssertFalse(vm.todos[0].isRunning)
        // runningTaskId is NOT cleared when keepWindowOpen == true
        XCTAssertEqual(vm.runningTaskId, taskId)
    }

    func testPauseTask_alsoStopsRunningSubtask() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // starts parent + auto-starts sub

        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isRunning)

        vm.pauseTask(vm.todos[0].id, keepWindowOpen: false)

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isRunning)
    }

    func testResumeTask_startsTimer_andSetsRunningTaskId() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id

        vm.resumeTask(taskId)

        XCTAssertTrue(vm.todos[0].isRunning)
        XCTAssertEqual(vm.runningTaskId, taskId)
    }

    func testResumeTask_setsStartedAt_onFirstResume() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        XCTAssertNil(vm.todos[0].startedAt)
        vm.resumeTask(vm.todos[0].id)
        XCTAssertNotNil(vm.todos[0].startedAt)
    }

    func testResumeTask_doesNotOverwriteStartedAt_onSubsequentResume() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let firstStartedAt = vm.todos[0].startedAt
        vm.pauseTask(vm.todos[0].id, keepWindowOpen: true)
        vm.resumeTask(vm.todos[0].id)
        XCTAssertEqual(vm.todos[0].startedAt, firstStartedAt)
    }

    // MARK: - createTask with switchToIt

    func testCreateTask_switchToIt_true_makesNewTaskRunning() {
        let (vm, _, _) = makeViewModel()
        vm.createTask(title: "New Task", switchToIt: true)
        XCTAssertEqual(vm.todos.count, 1)
        XCTAssertTrue(vm.todos[0].isRunning)
        XCTAssertEqual(vm.runningTaskId, vm.todos[0].id)
    }

    func testCreateTask_switchToIt_false_doesNotStartTask() {
        let (vm, _, _) = makeViewModel()
        vm.createTask(title: "New Task", switchToIt: false)
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNil(vm.runningTaskId)
    }

    func testCreateTask_switchToIt_true_stopsPreviouslyRunningTask() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Existing")]
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)

        vm.createTask(title: "New Task", switchToIt: true)

        XCTAssertFalse(vm.todos.first(where: { $0.text == "Existing" })!.isRunning)
        XCTAssertTrue(vm.todos.first(where: { $0.text == "New Task" })!.isRunning)
    }

    // MARK: - updateTaskFields — full field coverage

    func testUpdateTaskFields_updatesAllFields() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let id = vm.todos[0].id
        let dueDate = Date(timeIntervalSinceNow: 86400)

        vm.updateTaskFields(
            id: id,
            text: "Updated",
            description: "A description",
            notes: "Some notes",
            dueDate: dueDate,
            isAdhoc: true,
            fromWho: "Alice",
            estimatedTime: 1800
        )

        let task = vm.todos[0]
        XCTAssertEqual(task.text, "Updated")
        XCTAssertEqual(task.description, "A description")
        XCTAssertEqual(task.notes, "Some notes")
        XCTAssertEqual(task.dueDate, dueDate)
        XCTAssertTrue(task.isAdhoc)
        XCTAssertEqual(task.fromWho, "Alice")
        XCTAssertEqual(task.estimatedTime, 1800)
    }

    func testUpdateTaskFields_nilValues_doNotClearFields() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let id = vm.todos[0].id
        vm.updateTaskFields(id: id, text: "Set", description: "Desc", notes: nil,
                            dueDate: nil, isAdhoc: nil, fromWho: "Bob", estimatedTime: nil)
        // A second call with all-nil should not wipe what was set
        vm.updateTaskFields(id: id, text: nil, description: nil, notes: nil,
                            dueDate: nil, isAdhoc: nil, fromWho: nil, estimatedTime: nil)
        XCTAssertEqual(vm.todos[0].text, "Set")
        XCTAssertEqual(vm.todos[0].description, "Desc")
        XCTAssertEqual(vm.todos[0].fromWho, "Bob")
    }

    // MARK: - renameSubtask

    func testRenameSubtask_happyPath() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Old Name")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtask(sub, in: vm.todos[0], newTitle: "New Name")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "New Name")
    }

    func testRenameSubtask_whitespaceTrimmed() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Original")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtask(sub, in: vm.todos[0], newTitle: "  Trimmed  ")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Trimmed")
    }

    func testRenameSubtask_whitespaceOnly_doesNotRename() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Keep This")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtask(sub, in: vm.todos[0], newTitle: "   ")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Keep This")
    }

    // MARK: - switchToTask(byId:)

    func testSwitchToTaskById_stopsPreviousTask() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])

        vm.switchToTask(byId: vm.todos[1].id)

        XCTAssertFalse(vm.todos[0].isRunning)
    }

    func testSwitchToTaskById_autoPlays_whenEnabled() {
        let (vm, _, _) = makeViewModel()
        vm.autoPlayAfterSwitching = true
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        let targetId = vm.todos[1].id

        vm.switchToTask(byId: targetId)

        XCTAssertTrue(vm.todos.first(where: { $0.id == targetId })!.isRunning)
        XCTAssertEqual(vm.runningTaskId, targetId)
    }

    func testSwitchToTaskById_unknownId_doesNothing() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        vm.toggleTimer(vm.todos[0])

        vm.switchToTask(byId: UUID()) // unknown id

        // Original task should still be in the same state it was before (stopped,
        // because switchToTask always pauses the current task first)
        // — key invariant: no crash, todos unchanged in count
        XCTAssertEqual(vm.todos.count, 1)
    }

    // MARK: - toggleExpanded / toggleExpandAll

    func testToggleExpanded_insertsId_whenNotExpanded() {
        let (vm, _, _) = makeViewModel()
        let todo = makeTodo(text: "Task")
        vm.todos = [todo]

        vm.toggleExpanded(todo)

        XCTAssertTrue(vm.expandedTodos.contains(todo.id))
    }

    func testToggleExpanded_removesId_whenAlreadyExpanded() {
        let (vm, _, _) = makeViewModel()
        let todo = makeTodo(text: "Task")
        vm.todos = [todo]
        vm.toggleExpanded(todo)    // expand
        vm.toggleExpanded(todo)    // collapse

        XCTAssertFalse(vm.expandedTodos.contains(todo.id))
    }

    func testToggleExpandAll_expandsAllTasks() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B"), makeTodo(text: "C")]

        vm.toggleExpandAll()

        for todo in vm.todos {
            XCTAssertTrue(vm.expandedTodos.contains(todo.id))
        }
        XCTAssertTrue(vm.areAllTasksExpanded)
    }

    func testToggleExpandAll_collapsesAll_whenAlreadyExpanded() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleExpandAll() // expand all
        vm.toggleExpandAll() // collapse all

        XCTAssertTrue(vm.expandedTodos.isEmpty)
        XCTAssertFalse(vm.areAllTasksExpanded)
    }

    func testToggleExpanded_setsAreAllTasksExpanded_whenAllOpen() {
        let (vm, _, _) = makeViewModel()
        let t1 = makeTodo(text: "A")
        let t2 = makeTodo(text: "B")
        vm.todos = [t1, t2]

        vm.toggleExpanded(t1)
        XCTAssertFalse(vm.areAllTasksExpanded)
        vm.toggleExpanded(t2)
        XCTAssertTrue(vm.areAllTasksExpanded)
    }

    // MARK: - Auto-play on task switch with no incomplete subtasks

    func testSwitchToTask_autoPlay_noIncompleteSubtasks_noSubtaskTimerStarts() {
        let (vm, _, _) = makeViewModel()
        vm.autoPlayAfterSwitching = true
        let completedSub = makeSubtask(title: "Done", isCompleted: true)
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B", subtasks: [completedSub])]
        vm.toggleTimer(vm.todos[0])

        vm.switchToTask(vm.todos[1])

        // New task is running but no subtask timer should start (all are completed)
        XCTAssertTrue(vm.todos[1].isRunning)
        XCTAssertFalse(vm.todos[1].subtasks[0].isRunning)
    }

    // MARK: - Delete task while subtask timer running

    func testDeleteTask_whileSubtaskTimerRunning_noDanglingState() {
        let (vm, _, _) = makeViewModel()
        vm.confirmTaskDeletion = false
        let sub = makeSubtask(title: "Active Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // starts parent + sub auto-starts
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

        vm.deleteTodo(vm.todos[0])

        XCTAssertTrue(vm.todos.isEmpty)
        XCTAssertNil(vm.runningTaskId)
    }

    // MARK: - Phase 7: Notification ViewModel integration

    func testSetReminder_setsReminderDateOnTask() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id
        let date = Date().addingTimeInterval(3600)

        vm.setReminder(date, for: taskId)

        XCTAssertNotNil(vm.todos[0].reminderDate)
        XCTAssertEqual(vm.todos[0].reminderDate?.timeIntervalSince1970 ?? 0,
                       date.timeIntervalSince1970, accuracy: 1)
        NotificationScheduler.shared.cancel(for: taskId)
    }

    func testSetReminder_addsToSchedulerPending() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id
        let date = Date().addingTimeInterval(3600)

        vm.setReminder(date, for: taskId)

        XCTAssertNotNil(NotificationScheduler.shared.pending[taskId])
        NotificationScheduler.shared.cancel(for: taskId)
    }

    func testSetReminder_nil_clearsReminderDate() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id
        vm.setReminder(Date().addingTimeInterval(3600), for: taskId)

        vm.setReminder(nil, for: taskId)

        XCTAssertNil(vm.todos[0].reminderDate)
    }

    func testSetReminder_nil_removesFromSchedulerPending() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id
        vm.setReminder(Date().addingTimeInterval(3600), for: taskId)
        XCTAssertNotNil(NotificationScheduler.shared.pending[taskId])

        vm.setReminder(nil, for: taskId)

        XCTAssertNil(NotificationScheduler.shared.pending[taskId])
    }

    func testSetActiveNotification_true_setsFlag() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id

        vm.setActiveNotification(true, for: taskId)

        XCTAssertTrue(vm.todos[0].hasActiveNotification)
    }

    func testSetActiveNotification_false_clearsFlag() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id
        vm.setActiveNotification(true, for: taskId)

        vm.setActiveNotification(false, for: taskId)

        XCTAssertFalse(vm.todos[0].hasActiveNotification)
    }

    func testSetActiveNotification_unknownId_doesNotCrash() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.setActiveNotification(true, for: UUID()) // unknown id
        XCTAssertFalse(vm.todos[0].hasActiveNotification)
    }

    func testDismissBell_clearsHasActiveNotification() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id
        vm.setActiveNotification(true, for: taskId)
        XCTAssertTrue(vm.todos[0].hasActiveNotification)

        vm.dismissBell(for: taskId)

        XCTAssertFalse(vm.todos[0].hasActiveNotification)
    }

    func testDismissBell_dismissesNotificationStoreRecord() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let taskId = vm.todos[0].id

        // Plant a record in the store for this task
        NotificationStore.shared.setInitialRecords([
            NotificationRecord(taskId: taskId, taskTitle: "Task")
        ])

        vm.dismissBell(for: taskId)

        XCTAssertTrue(NotificationStore.shared.records.first?.isDismissed ?? false)
        NotificationStore.shared.setInitialRecords([])
    }

    // MARK: - Async persistence (Phase 2–4)

    func testSaveTask_persistsTaskAfterQueueDrains() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Async persist")]
        vm.toggleTimer(vm.todos[0])  // calls saveTask internally after the refactor
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()
        XCTAssertEqual(loaded?.first?.text, "Async persist")
        XCTAssertNotNil(loaded?.first?.lastStartTime)
    }

    func testSaveAllTasks_allTasksPersistedAfterDrain() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [
            TodoItem(text: "Task A", index: 0),
            TodoItem(text: "Task B", index: 1),
            TodoItem(text: "Task C", index: 2)
        ]
        vm.newTodoText = "Task D"
        vm.addTodo()  // triggers saveAllTasks (adds task, reindexes)
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()
        XCTAssertEqual(loaded?.count, 4)
        XCTAssertTrue(loaded?.contains(where: { $0.text == "Task D" }) == true)
    }

    func testToggleTimer_lastStartTime_persistedAfterDrain() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Timer task")]
        vm.toggleTimer(vm.todos[0])
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()
        XCTAssertNotNil(loaded?.first?.lastStartTime)
    }

    func testToggleSubtask_isCompleted_persistedAfterDrain() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0])
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtask(runningSub, in: vm.todos[0])
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()
        XCTAssertTrue(loaded?.first?.subtasks.contains(where: { $0.id == sub.id && $0.isCompleted }) == true)
    }

    func testPauseTask_lastStartTimeNil_persistedAfterDrain() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Pauseable")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id
        vm.pauseTask(taskId, keepWindowOpen: false)
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()
        XCTAssertNil(loaded?.first?.lastStartTime)
    }

    func testResumeTask_lastStartTime_persistedAfterDrain() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Resumeable")]
        let taskId = vm.todos[0].id
        vm.resumeTask(taskId)
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()
        XCTAssertNotNil(loaded?.first?.lastStartTime)
    }

    func testMoveTodo_indices_persistedAfterDrain() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [
            TodoItem(text: "A", index: 0),
            TodoItem(text: "B", index: 1),
            TodoItem(text: "C", index: 2)
        ]
        // Pre-save so they exist in DB
        for task in vm.todos { try? vm.sqliteStorage?.save(task) }

        vm.moveTodo(from: 0, to: 2)
        vm.sqliteStorage?.drainWrites()

        let loaded = try? vm.sqliteStorage?.load()  // sorted by index
        XCTAssertEqual(loaded?.map { $0.text }, ["B", "C", "A"])
    }

    func testDismissBell_unknownId_doesNotCrash() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        NotificationStore.shared.setInitialRecords([])
        vm.dismissBell(for: UUID()) // unknown id — should not crash
        XCTAssertFalse(vm.todos[0].hasActiveNotification)
    }
}
