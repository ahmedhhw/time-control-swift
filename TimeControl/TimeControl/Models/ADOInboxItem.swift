//
//  ADOInboxItem.swift
//  TimeControl
//

import Foundation

struct ADOInboxItem: Identifiable {
    let task: TodoItem
    let comments: [ADOComment]   // newest-first (as returned by ADOService.fetchComments)
    let lastSeenCommentId: Int?

    var id: UUID { task.id }

    var unreadCount: Int {
        guard let seen = lastSeenCommentId else { return comments.count }
        return comments.filter { $0.id > seen }.count
    }

    var hasUnread: Bool { unreadCount > 0 }

    /// The most recent comment whose id > lastSeenCommentId (i.e. newest unread).
    var latestUnreadComment: ADOComment? {
        guard let seen = lastSeenCommentId else { return comments.first }
        return comments.first { $0.id > seen }
    }

    /// The id of the newest comment overall — used to mark all as seen.
    var latestCommentId: Int? { comments.first?.id }
}
