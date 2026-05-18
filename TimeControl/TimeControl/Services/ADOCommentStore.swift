//
//  ADOCommentStore.swift
//  TimeControl
//

import Foundation

// MARK: - Protocol

protocol ADOUnreadCommentsStoreProtocol {
    func lastSeenCommentId(for taskId: UUID) -> Int?
    func markSeen(commentId: Int, for taskId: UUID)
    func hasUnread(latestCommentId: Int, for taskId: UUID) -> Bool
}

// MARK: - ADOUnreadCommentsStore

final class ADOUnreadCommentsStore: ADOUnreadCommentsStoreProtocol {
    private let defaults: UserDefaults
    private let key = "ado.unread.lastSeenCommentId"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastSeenCommentId(for taskId: UUID) -> Int? {
        let dict = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict[taskId.uuidString]
    }

    func markSeen(commentId: Int, for taskId: UUID) {
        var dict = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
        dict[taskId.uuidString] = commentId
        defaults.set(dict, forKey: key)
    }

    func hasUnread(latestCommentId: Int, for taskId: UUID) -> Bool {
        guard let seen = lastSeenCommentId(for: taskId) else {
            return latestCommentId > 0
        }
        return latestCommentId > seen
    }
}

// MARK: - SubtaskCommentPromptStore

final class SubtaskCommentPromptStore {
    private let defaults: UserDefaults
    private let key = "ado.subtask.alwaysPost"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func alwaysPost(for taskId: UUID) -> Bool {
        let dict = defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return dict[taskId.uuidString] ?? false
    }

    func setAlwaysPost(_ value: Bool, for taskId: UUID) {
        var dict = defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
        if value {
            dict[taskId.uuidString] = true
        } else {
            dict.removeValue(forKey: taskId.uuidString)
        }
        defaults.set(dict, forKey: key)
    }
}

enum SubtaskCompletionCommentBody {
    static func text(for subtaskTitle: String) -> String {
        "✓ Subtask completed: \(subtaskTitle)"
    }
}
