//
//  WindowOpacityApplier.swift
//  TimeControl
//

import AppKit

/// Applies translucency to a window WITHOUT dimming the SwiftUI content.
///
/// We deliberately keep `alphaValue` at 1.0 (which would fade everything,
/// text and controls included) and instead make the window non-opaque and
/// blend its background color. SwiftUI content painted on top stays at full
/// opacity, so labels and buttons remain crisp at any opacity level.
enum WindowOpacityApplier {

    static func apply(opacity: Double, to window: NSWindow) {
        let clamped = min(max(opacity, WindowOpacityStore.minimum), WindowOpacityStore.maximum)
        window.alphaValue = 1.0
        window.isOpaque = clamped >= 0.999
        let base = window.backgroundColor ?? NSColor.windowBackgroundColor
        window.backgroundColor = base.withAlphaComponent(CGFloat(clamped))
    }
}
