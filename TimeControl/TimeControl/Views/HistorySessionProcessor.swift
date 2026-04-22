//
//  HistorySessionProcessor.swift
//  TimeControl
//

import Foundation

struct SessionEntry {
    let taskId: UUID
    let subtaskId: UUID?
    let label: String
    let startedAt: TimeInterval
    let stoppedAt: TimeInterval
    var duration: TimeInterval { stoppedAt - startedAt }
}

enum HistorySessionProcessor {

    static let minSessionDuration: TimeInterval = 300  // 5 minutes
    static let mergeGapThreshold: TimeInterval = 120   // 2 minutes

    // Collects all completed sessions from todos that overlap `day`, clips them
    // to the day boundary, merges adjacent sessions of the same task/subtask,
    // then filters out merged sessions shorter than minSessionDuration.
    static func filteredSessions(
        from todos: [TodoItem],
        for day: Date,
        minDuration: TimeInterval = minSessionDuration,
        maxGap: TimeInterval = mergeGapThreshold
    ) -> [SessionEntry] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day).timeIntervalSince1970
        let dayEnd = dayStart + 86400

        var raw: [SessionEntry] = []

        for todo in todos {
            for session in todo.sessions {
                if let entry = clip(session, taskId: todo.id, subtaskId: nil, label: todo.text, dayStart: dayStart, dayEnd: dayEnd) {
                    raw.append(entry)
                }
            }
            for subtask in todo.subtasks {
                for session in subtask.sessions {
                    if let entry = clip(session, taskId: todo.id, subtaskId: subtask.id, label: subtask.title, dayStart: dayStart, dayEnd: dayEnd) {
                        raw.append(entry)
                    }
                }
            }
        }

        let merged = mergeSessions(raw, maxGap: maxGap)
        return merged.filter { $0.duration >= minDuration }
    }

    // Merges entries for the same (taskId, subtaskId) pair whose gap is < maxGap.
    // Entries are sorted by startedAt first, then merged per identity key, then re-sorted.
    static func mergeSessions(_ entries: [SessionEntry], maxGap: TimeInterval = mergeGapThreshold) -> [SessionEntry] {
        guard !entries.isEmpty else { return [] }

        // Group by identity key, preserving insertion order of first occurrence
        typealias Key = SessionKey
        var order: [Key] = []
        var groups: [Key: [SessionEntry]] = [:]

        for entry in entries {
            let key = Key(taskId: entry.taskId, subtaskId: entry.subtaskId)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(entry)
        }

        var result: [SessionEntry] = []
        for key in order {
            let sorted = groups[key]!.sorted { $0.startedAt < $1.startedAt }
            var merged: SessionEntry = sorted[0]
            for next in sorted.dropFirst() {
                let gap = next.startedAt - merged.stoppedAt
                if gap < maxGap {
                    merged = SessionEntry(
                        taskId: merged.taskId,
                        subtaskId: merged.subtaskId,
                        label: merged.label,
                        startedAt: merged.startedAt,
                        stoppedAt: max(merged.stoppedAt, next.stoppedAt)
                    )
                } else {
                    result.append(merged)
                    merged = next
                }
            }
            result.append(merged)
        }

        return result.sorted { $0.startedAt < $1.startedAt }
    }

    static func totalDuration(of entries: [SessionEntry]) -> TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Private

    private static func clip(
        _ session: TaskSession,
        taskId: UUID,
        subtaskId: UUID?,
        label: String,
        dayStart: TimeInterval,
        dayEnd: TimeInterval
    ) -> SessionEntry? {
        guard let stoppedAt = session.stoppedAt else { return nil }
        guard session.startedAt < dayEnd && stoppedAt > dayStart else { return nil }
        let clippedStart = max(session.startedAt, dayStart)
        let clippedEnd   = min(stoppedAt, dayEnd)
        guard clippedEnd > clippedStart else { return nil }
        return SessionEntry(taskId: taskId, subtaskId: subtaskId, label: label, startedAt: clippedStart, stoppedAt: clippedEnd)
    }
}

private struct SessionKey: Hashable {
    let taskId: UUID
    let subtaskId: UUID?
}
