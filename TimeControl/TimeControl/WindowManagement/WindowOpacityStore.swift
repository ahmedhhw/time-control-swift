//
//  WindowOpacityStore.swift
//  TimeControl
//

import Foundation

final class WindowOpacityStore {

    static let minimum: Double = 0.2
    static let maximum: Double = 1.0

    private let defaults: UserDefaults
    private let currentTaskKey = "floatingWindow.opacity"
    private let notesKey = "notesWindow.opacity"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentTaskOpacity: Double {
        get { read(currentTaskKey) }
        set { write(newValue, forKey: currentTaskKey) }
    }

    var notesOpacity: Double {
        get { read(notesKey) }
        set { write(newValue, forKey: notesKey) }
    }

    private func read(_ key: String) -> Double {
        if defaults.object(forKey: key) == nil { return Self.maximum }
        let value = defaults.double(forKey: key)
        return clamp(value)
    }

    private func write(_ value: Double, forKey key: String) {
        defaults.set(clamp(value), forKey: key)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, Self.minimum), Self.maximum)
    }
}
