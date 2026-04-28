//
//  WindowOpacityApplierTests.swift
//  TimeControlTests
//

import XCTest
import AppKit
@testable import TimeControl

final class WindowOpacityApplierTests: XCTestCase {

    private func makeWindow() -> NSWindow {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        return w
    }

    // MARK: - alphaValue must remain 1.0 (text/controls always fully visible)

    func testApply_leavesWindowAlphaValueAtOne() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: 0.4, to: window)
        XCTAssertEqual(window.alphaValue, 1.0, accuracy: 0.001,
                       "alphaValue must stay 1.0 — opacity is applied via backgroundColor only, so text/controls remain fully visible")
    }

    func testApply_leavesWindowAlphaValueAtOne_evenAtMinimum() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: WindowOpacityStore.minimum, to: window)
        XCTAssertEqual(window.alphaValue, 1.0, accuracy: 0.001)
    }

    // MARK: - Translucency happens via backgroundColor.alphaComponent

    func testApply_setsWindowNotOpaque_whenOpacityBelowOne() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: 0.5, to: window)
        XCTAssertFalse(window.isOpaque, "Window must be non-opaque so the translucent background can render")
    }

    func testApply_setsBackgroundColorAlphaToOpacity() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: 0.4, to: window)
        let alpha = window.backgroundColor?.alphaComponent ?? -1
        XCTAssertEqual(alpha, 0.4, accuracy: 0.01)
    }

    func testApply_atFullOpacity_setsBackgroundAlphaToOne() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: 1.0, to: window)
        let alpha = window.backgroundColor?.alphaComponent ?? -1
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }

    func testApply_atMinimumOpacity_setsBackgroundAlphaToMinimum() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: WindowOpacityStore.minimum, to: window)
        let alpha = window.backgroundColor?.alphaComponent ?? -1
        XCTAssertEqual(alpha, WindowOpacityStore.minimum, accuracy: 0.01)
    }

    // MARK: - Clamping

    func testApply_clampsAboveOne_toOne() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: 1.5, to: window)
        let alpha = window.backgroundColor?.alphaComponent ?? -1
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }

    func testApply_clampsBelowMinimum_toMinimum() {
        let window = makeWindow()
        WindowOpacityApplier.apply(opacity: 0.0, to: window)
        let alpha = window.backgroundColor?.alphaComponent ?? -1
        XCTAssertEqual(alpha, WindowOpacityStore.minimum, accuracy: 0.01)
    }
}
