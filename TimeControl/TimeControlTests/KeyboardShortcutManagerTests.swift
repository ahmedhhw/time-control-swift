//
//  KeyboardShortcutManagerTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class KeyboardShortcutManagerTests: XCTestCase {

    private var sut: KeyboardShortcutManager!

    override func setUp() {
        super.setUp()
        sut = KeyboardShortcutManager()
    }

    override func tearDown() {
        TaskPaletteWindowManager.shared.dismiss()
        QuickTimerWindowManager.shared.dismiss()
        FloatingWindowManager.shared.onOpenNotes = nil
        FloatingWindowManager.shared.onToggleCollapse = nil
        FloatingWindowManager.shared.notesViewerWindowRef = nil
        FloatingWindowManager.shared.onOpenNotesViewer = nil
        FloatingWindowManager.shared.closeFloatingWindow()
        sut = nil
        super.tearDown()
    }

    // MARK: - performToggleTimerKeepWindow

    func testPerformToggleTimer_noRunning_noTodos_doesNothing() {
        let (vm, _, _) = makeViewModel()

        sut.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertNil(vm.runningTaskId)
    }

    func testPerformToggleTimer_noRunning_picksMostRecentByLastPlayedAt() {
        let (vm, _, _) = makeViewModel()
        var older = makeTodo(text: "Older")
        older.lastPlayedAt = 100
        var newer = makeTodo(text: "Newer")
        newer.lastPlayedAt = 200
        vm.todos = [older, newer]

        sut.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertEqual(vm.runningTaskId, newer.id)
    }

    func testPerformToggleTimer_noRunning_skipsCompletedTodos() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [
            makeTodo(text: "Done A", isCompleted: true),
            makeTodo(text: "Done B", isCompleted: true)
        ]

        sut.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertNil(vm.runningTaskId)
    }

    func testPerformToggleTimer_running_pausesButKeepsRunningTaskId() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        XCTAssertNotNil(vm.todos[0].lastStartTime)
        let runningId = vm.runningTaskId

        sut.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertEqual(vm.runningTaskId, runningId)
        XCTAssertNil(vm.todos[0].lastStartTime)
    }

    func testPerformToggleTimer_pausedButRunningTaskIdSet_resumes() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let runningId = vm.runningTaskId!
        vm.pauseTask(runningId, keepWindowOpen: true)
        XCTAssertNil(vm.todos[0].lastStartTime)

        sut.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertEqual(vm.runningTaskId, runningId)
        XCTAssertNotNil(vm.todos[0].lastStartTime)
    }

    func testPerformToggleTimer_roundTrip_endsRunning() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]

        sut.performToggleTimerKeepWindow(viewModel: vm) // start
        sut.performToggleTimerKeepWindow(viewModel: vm) // pause
        sut.performToggleTimerKeepWindow(viewModel: vm) // resume

        XCTAssertNotNil(vm.runningTaskId)
        XCTAssertNotNil(vm.todos[0].lastStartTime)
    }

    // MARK: - performShowTaskSwitcher

    func testPerformShowTaskSwitcher_makesPaletteVisible() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]

        sut.performShowTaskSwitcher(viewModel: vm)

        XCTAssertTrue(TaskPaletteWindowManager.shared.isVisible)
    }

    // MARK: - performShowQuickTimer

    func testPerformShowQuickTimer_makesQuickTimerVisible() {
        let (vm, _, _) = makeViewModel()

        sut.performShowQuickTimer(viewModel: vm)

        XCTAssertTrue(QuickTimerWindowManager.shared.isVisible)
    }

    // MARK: - performToggleNotes

    func testPerformToggleNotes_invokesOnOpenNotesCallback_whenNoNotesWindow() {
        var fulfilled = false
        FloatingWindowManager.shared.notesWindowRef = nil
        FloatingWindowManager.shared.onOpenNotes = { fulfilled = true }

        sut.performToggleNotes()

        XCTAssertTrue(fulfilled)
    }

    // MARK: - performToggleFloatingWindowCollapse

    func testPerformToggleFloatingWindowCollapse_noOpWhenWindowClosed() {
        var fired = false
        // Ensure window is closed.
        FloatingWindowManager.shared.closeFloatingWindow()
        XCTAssertFalse(FloatingWindowManager.shared.isWindowOpen)
        // Set a callback that should NOT fire while window is closed.
        FloatingWindowManager.shared.onToggleCollapse = { fired = true }

        sut.performToggleFloatingWindowCollapse()

        XCTAssertFalse(fired)
    }

    // MARK: - performToggleNotesViewer

    func testPerformToggleNotesViewer_nilWindowRef_firesOpenCallback() {
        var fulfilled = false
        FloatingWindowManager.shared.notesViewerWindowRef = nil
        FloatingWindowManager.shared.onOpenNotesViewer = { fulfilled = true }

        sut.performToggleNotesViewer()

        XCTAssertTrue(fulfilled)
    }

    func testPerformToggleNotesViewer_windowNotVisible_firesOpenCallback() {
        var fulfilled = false
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        FloatingWindowManager.shared.notesViewerWindowRef = window
        FloatingWindowManager.shared.onOpenNotesViewer = { fulfilled = true }

        sut.performToggleNotesViewer()

        XCTAssertTrue(fulfilled)
    }

    func testPerformToggleNotesViewer_windowVisibleAndKey_doesNotFireCallback() throws {
        var fulfilled = false
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.orderFrontRegardless()
        window.makeKey()
        // In headless CI / test runners the window server may refuse to grant key status.
        try XCTSkipUnless(window.isKeyWindow, "Window could not become key in this environment")
        FloatingWindowManager.shared.notesViewerWindowRef = window
        FloatingWindowManager.shared.onOpenNotesViewer = { fulfilled = true }

        sut.performToggleNotesViewer()

        XCTAssertFalse(fulfilled)
        window.close()
    }

    func testPerformToggleFloatingWindowCollapse_invokesCallbackWhenWindowOpen() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Open task")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        XCTAssertTrue(FloatingWindowManager.shared.isWindowOpen)
        // Replace whatever the view's onAppear may have registered with a test spy.
        var fired = false
        FloatingWindowManager.shared.onToggleCollapse = { fired = true }

        sut.performToggleFloatingWindowCollapse()

        XCTAssertTrue(fired)
    }
}
