# History Window — Crash/Freeze on Second Launch

## Symptom
Clicking the History toolbar button a second time (after closing the History window once) crashes or freezes the app.

## Root cause
The bug lives in [openHistoryWindow()](TimeControl/TimeControl/ContentView.swift#L426-L464). Two interacting problems:

### 1. `isReleasedWhenClosed` defaults to `true` for `NSWindow`
The window is constructed with the plain `NSWindow(contentRect:styleMask:backing:defer:)` initializer:

```swift
let window = NSWindow(
    contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
// ...
historyWindow = window
```

For `NSWindow` created this way, `isReleasedWhenClosed` defaults to **true**. That property dates back to manual reference counting: when the user clicks the close button, AppKit sends an extra `release` to the window. Under ARC this collides with Swift's automatic retain on `@State private var historyWindow: NSWindow?`, leaving the `@State` slot pointing at a window whose AppKit-side state has been torn down (a "zombie" — alive to ARC, dead to AppKit).

Apple's own guidance (and SwiftUI's `NSHostingController`-based windows) is to set `isReleasedWhenClosed = false` whenever you keep your own strong reference. That line is missing here.

### 2. Calling `close()` on the stale reference on the second launch
When the function runs the second time, `historyWindow` is non-nil but `isVisible` is `false` (the user already closed it), so the early-return branch is skipped and execution falls into:

```swift
historyWindow?.close()
```

That sends `close` to the zombie NSWindow from step 1. The window already ran its close path once, so this second `close()` re-enters AppKit's teardown on a half-deallocated object — which is what produces the crash (`EXC_BAD_ACCESS` / over-release) or, in some builds, a hang inside AppKit's window-cleanup code (the freeze).

### 3. Nothing clears `historyWindow` when the window actually closes
There is no `NSWindowDelegate`, no `windowWillClose`/`windowDidClose` observer, and no Combine subscription on `NSWindow.willCloseNotification`. So after the user closes the window, `historyWindow` is never set back to `nil`. That is why the second invocation always lands in the dangerous `historyWindow?.close()` branch instead of falling straight through to "create a fresh window."

## Why `openNotesViewerWindow()` doesn't crash the same way
The notes viewer at [ContentView.swift:466-507](TimeControl/TimeControl/ContentView.swift#L466-L507) has the *same* logical bug, but it constructs an `NSPanel` configured as a floating panel (`.nonactivatingPanel`, `isFloatingPanel = true`, `level = .floating`). Floating panels typically hide on close instead of going through the full release-on-close teardown, which masks the issue. The history window uses a regular `NSWindow`, so it gets the full default behavior.

## Fix sketch (for reference, not applied here)
Three small changes together resolve it:

1. After creating the window, add `window.isReleasedWhenClosed = false`.
2. Observe `NSWindow.willCloseNotification` (or assign an `NSWindowDelegate`) and set `historyWindow = nil` when the window closes.
3. With (1) and (2) in place, the `historyWindow?.close()` line right before constructing a new window becomes unnecessary and should be removed — by then `historyWindow` is either `nil` or a still-visible window already handled by the early-return branch.
