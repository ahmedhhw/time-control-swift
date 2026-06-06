//
//  KeyboardShortcutManagerTests.swift
//  TimeControlTests
//

import XCTest
import KeyboardShortcuts
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
        CommandPaletteWindowManager.shared.dismiss()
        FloatingWindowManager.shared.onOpenNotes = nil
        FloatingWindowManager.shared.onToggleCollapse = nil
        FloatingWindowManager.shared.onOpenADOAndFocusComment = nil
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput = nil
        FloatingWindowManager.shared.notesViewerWindowRef = nil
        FloatingWindowManager.shared.historyWindowRef = nil
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

    // MARK: - Notification crash guards (Phase 4)

    func testPostingFocusADOCommentFieldNotification_doesNotCrash() {
        XCTAssertNoThrow(
            NotificationCenter.default.post(name: .focusADOCommentField, object: nil)
        )
    }

    func testPostingOpenHistoryWindowNotification_doesNotCrash() {
        XCTAssertNoThrow(
            NotificationCenter.default.post(name: .openHistoryWindow, object: nil)
        )
    }

    // MARK: - FloatingWindowManager callbacks (Phase 2)

    func testFloatingWindowManager_hasADOCommentCallback_settable() {
        var fired = false
        FloatingWindowManager.shared.onOpenADOAndFocusComment = { fired = true }
        FloatingWindowManager.shared.onOpenADOAndFocusComment?()
        XCTAssertTrue(fired)
    }

    func testFloatingWindowManager_hasSubtaskInputCallback_settable() {
        var fired = false
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput = { fired = true }
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput?()
        XCTAssertTrue(fired)
    }

    func testFloatingWindowManager_clearWindowState_nilsNewCallbacks() {
        FloatingWindowManager.shared.onOpenADOAndFocusComment = { }
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput = { }
        FloatingWindowManager.shared.clearWindowState()
        XCTAssertNil(FloatingWindowManager.shared.onOpenADOAndFocusComment)
        XCTAssertNil(FloatingWindowManager.shared.onOpenSubtasksAndFocusInput)
    }

    // MARK: - showCentered / performShowTaskSwitcher (Phase 1)

    // MARK: - performOpenADOComment (Phase 3)

    func testPerformOpenADOComment_noWindow_doesNotFireCallback() {
        FloatingWindowManager.shared.closeFloatingWindow()
        var fired = false
        FloatingWindowManager.shared.onOpenADOAndFocusComment = { fired = true }

        sut.performOpenADOComment()

        XCTAssertFalse(fired)
    }

    func testPerformOpenADOComment_windowOpen_taskHasADOId_firesCallback() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "ADO Task", adoWorkItemId: "1234")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        var fired = false
        FloatingWindowManager.shared.onOpenADOAndFocusComment = { fired = true }

        sut.performOpenADOComment()

        XCTAssertTrue(fired)
    }

    func testPerformOpenADOComment_windowOpen_taskHasNoADOId_doesNotFireCallback() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "No ADO")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        var fired = false
        FloatingWindowManager.shared.onOpenADOAndFocusComment = { fired = true }

        sut.performOpenADOComment()

        XCTAssertFalse(fired)
    }

    // MARK: - performOpenSubtaskInput (Phase 3)

    func testPerformOpenSubtaskInput_noWindow_doesNotFireCallback() {
        FloatingWindowManager.shared.closeFloatingWindow()
        var fired = false
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput = { fired = true }

        sut.performOpenSubtaskInput()

        XCTAssertFalse(fired)
    }

    func testPerformOpenSubtaskInput_windowOpen_firesCallback() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Task")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        var fired = false
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput = { fired = true }

        sut.performOpenSubtaskInput()

        XCTAssertTrue(fired)
    }

    // MARK: - performOpenHistory (toggle)

    func testPerformOpenHistory_postsOpenHistoryWindowNotification() {
        let expectation = XCTestExpectation(description: "openHistoryWindow notification")
        let token = NotificationCenter.default.addObserver(
            forName: .openHistoryWindow, object: nil, queue: .main
        ) { _ in expectation.fulfill() }

        sut.performOpenHistory()

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformOpenHistory_nilWindowRef_postsNotification() {
        FloatingWindowManager.shared.historyWindowRef = nil
        let expectation = XCTestExpectation(description: "openHistoryWindow notification posted")
        let token = NotificationCenter.default.addObserver(
            forName: .openHistoryWindow, object: nil, queue: .main
        ) { _ in expectation.fulfill() }

        sut.performOpenHistory()

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformOpenHistory_windowNotVisible_postsNotification() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        FloatingWindowManager.shared.historyWindowRef = window
        let expectation = XCTestExpectation(description: "openHistoryWindow notification posted")
        let token = NotificationCenter.default.addObserver(
            forName: .openHistoryWindow, object: nil, queue: .main
        ) { _ in expectation.fulfill() }

        sut.performOpenHistory()

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformOpenHistory_windowVisible_closesWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.orderFrontRegardless()
        XCTAssertTrue(window.isVisible)
        FloatingWindowManager.shared.historyWindowRef = window

        sut.performOpenHistory()

        XCTAssertFalse(window.isVisible)
    }

    func testPerformOpenHistory_windowVisibleAndKey_closesWindow_doesNotPostNotification() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.orderFrontRegardless()
        window.makeKey()
        try XCTSkipUnless(window.isKeyWindow, "Window could not become key in this environment")
        FloatingWindowManager.shared.historyWindowRef = window
        var notificationFired = false
        let token = NotificationCenter.default.addObserver(
            forName: .openHistoryWindow, object: nil, queue: .main
        ) { _ in notificationFired = true }

        sut.performOpenHistory()

        XCTAssertFalse(notificationFired)
        XCTAssertFalse(window.isVisible)
        NotificationCenter.default.removeObserver(token)
    }

    // MARK: - performShowMainWindow (toggle)

    func testPerformShowMainWindow_noVisibleNonPanelWindow_doesNotCrash() {
        XCTAssertNoThrow(sut.performShowMainWindow())
    }

    func testPerformShowMainWindow_windowVisibleAndKey_hidesWindow() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.orderFrontRegardless()
        window.makeKey()
        try XCTSkipUnless(window.isKeyWindow, "Window could not become key in this environment")
        XCTAssertTrue(window.isVisible)

        sut.performShowMainWindow()

        XCTAssertFalse(window.isVisible)
        window.close()
    }

    // MARK: - activateFloatingWindow (Phase 1)

    func testActivateFloatingWindow_noWindow_doesNotCrash() {
        FloatingWindowManager.shared.closeFloatingWindow()
        XCTAssertNoThrow(FloatingWindowManager.shared.activateFloatingWindow())
    }

    func testActivateFloatingWindow_withWindow_doesNotCrash() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Task")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        XCTAssertNoThrow(FloatingWindowManager.shared.activateFloatingWindow())
    }

    // MARK: - performOpenADOComment + performOpenSubtaskInput activate window (Phase 4)

    func testPerformOpenADOComment_windowOpen_taskHasADOId_activatesAndFiresCallback() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "ADO Task", adoWorkItemId: "1234")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        var fired = false
        FloatingWindowManager.shared.onOpenADOAndFocusComment = { fired = true }

        sut.performOpenADOComment()

        XCTAssertTrue(fired)
    }

    func testPerformOpenSubtaskInput_windowOpen_activatesAndFiresCallback() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Task")
        vm.todos = [task]
        FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: vm)
        var fired = false
        FloatingWindowManager.shared.onOpenSubtasksAndFocusInput = { fired = true }

        sut.performOpenSubtaskInput()

        XCTAssertTrue(fired)
    }

    // MARK: - setup registers shortcuts (Phase 3)

    func testSetup_registersAllShortcutsWithoutCrashing() {
        let (vm, _, _) = makeViewModel()
        let manager = KeyboardShortcutManager()
        XCTAssertNoThrow(manager.setup(viewModel: vm))
    }

    // MARK: - Keyboard Shortcuts Settings (reset new shortcuts)

    func testResetNewShortcuts_restoresDefaults_doesNotCrash() {
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .openADOComment)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .sendADOComment)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .openSubtaskInput)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .openHistory)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .showMainWindow)

        XCTAssertNoThrow(
            KeyboardShortcuts.reset(
                .openADOComment,
                .sendADOComment,
                .openSubtaskInput,
                .openHistory,
                .showMainWindow
            )
        )

        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .openADOComment),   .init(.a, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .sendADOComment),   .init(.return, modifiers: .command))
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .openSubtaskInput), .init(.t, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .openHistory),      .init(.h, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .showMainWindow),   .init(.m, modifiers: [.command, .shift]))
    }

    func testSendADOCommentShortcut_defaultIsCmdReturn() {
        KeyboardShortcuts.reset(.sendADOComment)
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .sendADOComment),
            .init(.return, modifiers: .command)
        )
    }

    // MARK: - showCentered / performShowTaskSwitcher (Phase 1)

    func testShowCentered_makesPaletteVisible() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]

        TaskPaletteWindowManager.shared.showCentered(viewModel: vm)

        XCTAssertTrue(TaskPaletteWindowManager.shared.isVisible)
    }

    func testPerformShowTaskSwitcher_stillMakesPaletteVisible_afterCenteredRefactor() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]

        sut.performShowTaskSwitcher(viewModel: vm)

        XCTAssertTrue(TaskPaletteWindowManager.shared.isVisible)
    }

    // MARK: - performShowCommandPalette

    func testPerformShowCommandPalette_makesPaletteVisible() {
        let (vm, _, _) = makeViewModel()

        sut.performShowCommandPalette(viewModel: vm)

        XCTAssertTrue(CommandPaletteWindowManager.shared.isVisible)
    }

    // MARK: - commandPalette shortcut default

    func testCommandPaletteShortcut_defaultIsCmdShiftL() {
        KeyboardShortcuts.reset(.commandPalette)
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .commandPalette),
            .init(.l, modifiers: [.command, .shift])
        )
    }

    func testResetCommandPaletteShortcut_restoresDefault() {
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .commandPalette)
        KeyboardShortcuts.reset(.commandPalette)
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .commandPalette),
            .init(.l, modifiers: [.command, .shift])
        )
    }

    func testSetup_registersCommandPaletteWithoutCrashing() {
        let (vm, _, _) = makeViewModel()
        let manager = KeyboardShortcutManager()
        XCTAssertNoThrow(manager.setup(viewModel: vm))
    }

    func testResetAllShortcuts_includesCommandPalette_doesNotCrash() {
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: .control), for: .commandPalette)
        XCTAssertNoThrow(KeyboardShortcuts.reset(.commandPalette))
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .commandPalette),
            .init(.l, modifiers: [.command, .shift])
        )
    }
}
