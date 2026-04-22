//
//  NotificationStore.swift
//  TimeControl
//

import Foundation
import Combine

final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    private static let userDefaultsKey = "notificationRecords"

    @Published private(set) var records: [NotificationRecord] = []

    // Set by TodoViewModel so mutations here trigger a unified save
    var onNeedsSave: (() -> Void)?

    private init() {}

    // MARK: - Setup

    func setInitialRecords(_ records: [NotificationRecord]) {
        self.records = records
    }

    // MARK: - UserDefaults persistence

    func saveToUserDefaults(defaults: UserDefaults = .standard) {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let trimmed = records.filter { $0.firedAt > cutoff }
        if let data = try? JSONEncoder().encode(trimmed) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    static func loadFromUserDefaults(defaults: UserDefaults = .standard) -> [NotificationRecord] {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([NotificationRecord].self, from: data)
        else { return [] }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return decoded.filter { $0.firedAt > cutoff }.sorted { $0.firedAt > $1.firedAt }
    }

    // MARK: - Public API

    func append(_ record: NotificationRecord) {
        records.insert(record, at: 0)
        onNeedsSave?()
    }

    func dismiss(taskId: UUID) {
        var changed = false
        for i in records.indices {
            if records[i].taskId == taskId && !records[i].isDismissed {
                records[i].isDismissed = true
                changed = true
            }
        }
        if changed {
            onNeedsSave?()
        }
    }
}
