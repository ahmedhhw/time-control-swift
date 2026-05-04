//
//  ADOUser.swift
//  TimeControl
//

import Foundation

struct ADOUser: Identifiable, Equatable {
    let id: String          // subjectDescriptor
    let displayName: String
    let mailAddress: String
}

struct MentionToken: Equatable {
    let displayName: String
    let descriptor: String
    var storageKey: String?
}
