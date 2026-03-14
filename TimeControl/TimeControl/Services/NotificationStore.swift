//
//  NotificationStore.swift
//  TimeControl
//

import Foundation
import Combine

final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published private(set) var records: [NotificationRecord] = []

    // Set by TodoViewModel so mutations here trigger a unified save
    var onNeedsSave: (() -> Void)?

    private init() {}

    // MARK: - Setup

    func setInitialRecords(_ records: [NotificationRecord]) {
        self.records = records
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
