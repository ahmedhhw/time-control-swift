//
//  PastedImage.swift
//  TimeControl
//

import Foundation

struct PastedImage: Identifiable {
    let id: UUID
    let filename: String
    let data: Data
    var uploadState: UploadState

    enum UploadState: Equatable {
        case pending
        case uploading
        case uploaded(URL)
        case failed
    }
}
