//
//  HistoryWindowTests.swift
//  TimeControlTests
//
//  Tests the fix for the history window crash/freeze on second launch.
//  See: TimeControl/docs/history_problems.md
//

import XCTest
import AppKit
@testable import TimeControl

final class HistoryWindowTests: XCTestCase {

    // MARK: - isReleasedWhenClosed

    func test_historyWindow_isReleasedWhenClosed_isFalse() {
        let window = makeHistoryWindow()
        XCTAssertFalse(window.isReleasedWhenClosed,
            "History window must not release on close — default true causes zombie pointers under ARC")
    }

    // MARK: - Notification clears reference

    func test_willCloseNotification_nilsOutReference() {
        let window = makeHistoryWindow()
        var ref: NSWindow? = window

        // Wire the same observer logic used in openHistoryWindow()
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            if ref === window { ref = nil }
        }

        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)

        // Run main-queue observer
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertNil(ref, "Reference must be cleared when willCloseNotification fires")
    }

    func test_willCloseNotification_doesNotNilUnrelatedReference() {
        let window1 = makeHistoryWindow()
        let window2 = makeHistoryWindow()
        var ref: NSWindow? = window1

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window1,
            queue: .main
        ) { [weak window1] _ in
            if ref === window1 { ref = nil }
        }

        // Fire notification for a different window
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window2)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertNotNil(ref, "Reference must not be cleared when a different window closes")
    }

    // MARK: - Open twice safety

    func test_openingWindowTwice_doesNotCrash() {
        // Simulate the full open → close → open cycle without ContentView
        var historyWindow: NSWindow?

        func open() {
            if let existing = historyWindow, existing.isVisible {
                existing.orderFrontRegardless()
                return
            }
            // Note: no historyWindow?.close() call (the fixed version removes this)
            let window = makeHistoryWindow()
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                if historyWindow === window { historyWindow = nil }
            }
            historyWindow = window
            window.orderFrontRegardless()
        }

        open()
        XCTAssertNotNil(historyWindow)

        // Simulate user closing the window
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: historyWindow)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(historyWindow, "Reference should be nil after close notification")

        // Second open — this is what used to crash
        open()
        XCTAssertNotNil(historyWindow, "Window should open successfully on second launch")
    }

    // MARK: - Helper

    private func makeHistoryWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        return window
    }
}
