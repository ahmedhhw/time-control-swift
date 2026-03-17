//
//  Enums.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import Foundation

enum TaskSortOption: String, CaseIterable, Identifiable {
    case creationDateNewest = "Newest First"
    case creationDateOldest = "Oldest First"
    case recentlyPlayedNewest = "Recently Played (Newest First)"
    case dueDateNearest = "Due Date (Nearest First)"
    
    var id: String { self.rawValue }
}

enum MassOperationType: String, CaseIterable, Identifiable {
    case fill = "Fill field for tasks"
    case edit = "Edit field for tasks"
    
    var id: String { self.rawValue }
}

enum EditableField: String, CaseIterable, Identifiable {
    case title = "Title"
    case description = "Description"
    case notes = "Notes"
    case fromWho = "From Who"
    case adhoc = "Adhoc"
    case estimation = "Estimation"
    case dueDate = "Due Date"
    
    var id: String { self.rawValue }
}

enum AutoPauseDuration: Int, CaseIterable, Identifiable {
    case off = 0
    case oneMinute = 1
    case twoMinutes = 2
    case threeMinutes = 3
    case fourMinutes = 4
    case fiveMinutes = 5
    case sixMinutes = 6
    case sevenMinutes = 7
    case eightMinutes = 8
    case nineMinutes = 9
    case tenMinutes = 10

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        default: return "\(rawValue) minute\(rawValue == 1 ? "" : "s")"
        }
    }
}

enum DefaultTimerDuration: Int, CaseIterable, Identifiable {
    case off = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case twentyMinutes = 20
    case twentyFiveMinutes = 25
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case oneHour = 60
    case ninetyMinutes = 90
    case twoHours = 120

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .oneHour: return "1 hour"
        case .ninetyMinutes: return "1.5 hours"
        case .twoHours: return "2 hours"
        default: return "\(rawValue) minutes"
        }
    }
}

enum ReminderResponse {
    case yes
    case pause
    case openTaskList
}

enum DropdownSortOption: String, CaseIterable, Identifiable {
    case recentlyPlayed = "Recently played"
    case newest = "Newest created"
    case oldest = "Oldest created"
    case estimateSize = "Smallest estimate"
    case dueDate = "Nearest due date"

    var id: String { self.rawValue }
}
