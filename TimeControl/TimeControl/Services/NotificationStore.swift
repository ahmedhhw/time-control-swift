//
//  NotificationStore.swift
//  TimeControl
//

import Foundation
import Combine

final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published private(set) var records: [NotificationRecord] = []

    private static let storageURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("notification_records.json")
    }()

    private init() {
        load()
    }

    // MARK: - Public API

    func append(_ record: NotificationRecord) {
        records.insert(record, at: 0)
        save()
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
            save()
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: Self.storageURL)
            let decoded = try JSONDecoder().decode([NotificationRecord].self, from: data)

            // Prune records older than 30 days
            let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            records = decoded
                .filter { $0.firedAt > cutoff }
                .sorted { $0.firedAt > $1.firedAt }
        } catch {
            print("NotificationStore: load failed: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: Self.storageURL)
        } catch {
            print("NotificationStore: save failed: \(error)")
        }
    }
}
