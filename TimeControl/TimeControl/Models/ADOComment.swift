//
//  ADOComment.swift
//  TimeControl
//

import Foundation

struct ADOComment: Identifiable, Equatable {
    let id: Int
    let text: String
    let authorDisplayName: String
    let createdDate: Date

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdDate, relativeTo: Date())
    }
}
