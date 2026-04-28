//
//  ADOURLBuilder.swift
//  TimeControl
//

import Foundation

struct ADOURLBuilder {

    private let settings: ADOSettingsStore

    init(settings: ADOSettingsStore = ADOSettingsStore()) {
        self.settings = settings
    }

    func buildURL(id: String) -> URL? {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return nil }

        let org = settings.organization
        let project = settings.project
        guard !org.isEmpty, !project.isEmpty else { return nil }

        guard let encodedProject = project.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        return URL(string: "https://dev.azure.com/\(org)/\(encodedProject)/_workitems/edit/\(trimmedId)")
    }

    /// Accepts either a bare numeric ID or a full ADO URL containing
    /// `/_workitems/edit/<digits>`. Returns the numeric ID, or `nil` if neither matches.
    static func extractId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let match = trimmed.range(of: #"/_workitems/edit/(\d+)"#, options: .regularExpression) {
            let digitsRange = trimmed[match]
            if let idStart = digitsRange.range(of: #"\d+"#, options: .regularExpression) {
                return String(digitsRange[idStart])
            }
        }

        if trimmed.range(of: #"^\d+$"#, options: .regularExpression) != nil {
            return trimmed
        }

        return nil
    }
}
