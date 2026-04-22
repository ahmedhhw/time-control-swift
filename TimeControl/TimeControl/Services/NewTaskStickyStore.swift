//
//  NewTaskStickyStore.swift
//  TimeControl
//

import Foundation

struct NewTaskStickyFields {
    var hasDueDate: Bool
    var dueDate: Date
    var estimateHours: Int
    var estimateMinutes: Int
    var switchToTask: Bool
    var copyNotes: Bool

    static let defaults = NewTaskStickyFields(
        hasDueDate: false,
        dueDate: Date(),
        estimateHours: 0,
        estimateMinutes: 0,
        switchToTask: false,
        copyNotes: false
    )
}

struct NewTaskStickyStore {
    private enum Keys {
        static let hasDueDate = "newTaskStickyHasDueDate"
        static let dueDate = "newTaskStickyDueDate"
        static let estimateHours = "newTaskStickyEstimateHours"
        static let estimateMinutes = "newTaskStickyEstimateMinutes"
        static let switchToTask = "newTaskStickySwitchToTask"
        static let copyNotes = "newTaskStickyCopyNotes"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(
        hasDueDate: Bool,
        dueDate: Date,
        estimateHours: Int,
        estimateMinutes: Int,
        switchToTask: Bool,
        copyNotes: Bool
    ) {
        defaults.set(hasDueDate, forKey: Keys.hasDueDate)
        defaults.set(dueDate.timeIntervalSince1970, forKey: Keys.dueDate)
        defaults.set(estimateHours, forKey: Keys.estimateHours)
        defaults.set(estimateMinutes, forKey: Keys.estimateMinutes)
        defaults.set(switchToTask, forKey: Keys.switchToTask)
        defaults.set(copyNotes, forKey: Keys.copyNotes)
    }

    func load() -> NewTaskStickyFields {
        let rawDate = defaults.double(forKey: Keys.dueDate)
        let dueDate = rawDate == 0 ? Date() : Date(timeIntervalSince1970: rawDate)
        return NewTaskStickyFields(
            hasDueDate: defaults.bool(forKey: Keys.hasDueDate),
            dueDate: dueDate,
            estimateHours: defaults.integer(forKey: Keys.estimateHours),
            estimateMinutes: defaults.integer(forKey: Keys.estimateMinutes),
            switchToTask: defaults.bool(forKey: Keys.switchToTask),
            copyNotes: defaults.bool(forKey: Keys.copyNotes)
        )
    }

    func clear() {
        defaults.removeObject(forKey: Keys.hasDueDate)
        defaults.removeObject(forKey: Keys.dueDate)
        defaults.removeObject(forKey: Keys.estimateHours)
        defaults.removeObject(forKey: Keys.estimateMinutes)
        defaults.removeObject(forKey: Keys.switchToTask)
        defaults.removeObject(forKey: Keys.copyNotes)
    }

    func applyOrReset(stickyEnabled: Bool) -> NewTaskStickyFields {
        if stickyEnabled {
            return load()
        } else {
            return .defaults
        }
    }
}
