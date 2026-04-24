//
//  NotesWindowFrameStore.swift
//  TimeControl
//

import AppKit

/// NSWindowDelegate that saves the notes window frame whenever it moves, resizes, or closes.
final class NotesWindowDelegate: NSObject, NSWindowDelegate {
    private let store: NotesWindowFrameStore

    init(store: NotesWindowFrameStore) {
        self.store = store
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        store.save(window.frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        store.save(window.frame)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        store.save(window.frame)
    }
}

/// Persists the notes window frame (origin + size) across app launches via UserDefaults.
final class NotesWindowFrameStore {

    static let minSize = NSSize(width: 180, height: 120)

    private let key: String

    init(userDefaultsKey: String = "notesWindowFrame") {
        self.key = userDefaultsKey
    }

    func save(_ frame: NSRect) {
        let dict: [String: Double] = [
            "x": Double(frame.origin.x),
            "y": Double(frame.origin.y),
            "w": Double(frame.size.width),
            "h": Double(frame.size.height)
        ]
        UserDefaults.standard.set(dict, forKey: key)
    }

    func load() -> NSRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: key),
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double,
              let w = dict["w"] as? Double,
              let h = dict["h"] as? Double else { return nil }

        let width  = max(CGFloat(w), Self.minSize.width)
        let height = max(CGFloat(h), Self.minSize.height)
        return NSRect(x: CGFloat(x), y: CGFloat(y), width: width, height: height)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
