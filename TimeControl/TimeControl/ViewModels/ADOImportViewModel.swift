//
//  ADOImportViewModel.swift
//  TimeControl
//

import Foundation

@MainActor
final class ADOImportViewModel: ObservableObject {

    @Published var workItemIdText: String = ""
    @Published var fetchedItem: ADOWorkItem?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: ADOService
    private let settings: ADOSettingsStore

    init(service: ADOService = ADOService(), settings: ADOSettingsStore = ADOSettingsStore()) {
        self.service = service
        self.settings = settings
    }

    var canFetch: Bool {
        guard let id = ADOURLBuilder.extractId(from: workItemIdText) else { return false }
        guard !id.isEmpty else { return false }
        return !settings.organization.isEmpty && !settings.project.isEmpty && !settings.pat.isEmpty
    }

    func fetchWorkItem() async {
        guard let idString = ADOURLBuilder.extractId(from: workItemIdText),
              !idString.isEmpty,
              let id = Int(idString) else { return }

        isLoading = true
        errorMessage = nil
        fetchedItem = nil

        do {
            let item = try await service.fetchWorkItem(
                org: settings.organization,
                project: settings.project,
                id: id,
                pat: settings.pat
            )
            fetchedItem = item
        } catch ADOService.ADOError.unauthorized {
            errorMessage = "Authentication failed (401) — check your PAT in Settings."
        } catch ADOService.ADOError.notFound {
            errorMessage = "Work item not found (404). Check the ID and try again."
        } catch ADOService.ADOError.networkUnavailable {
            errorMessage = "Can't reach ADO — check your network connection."
        } catch ADOService.ADOError.tlsError {
            errorMessage = "TLS error — if on a corporate network, contact IT to install the root certificate."
        } catch ADOService.ADOError.serverError(let code) {
            errorMessage = "Server error (\(code)). Try again later."
        } catch ADOService.ADOError.urlError(let code) {
            errorMessage = "Network error (URLError \(code)) — check your connection and try again."
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func importAsNewTask() -> TodoItem? {
        guard let item = fetchedItem else { return nil }
        let plainDescription = stripHTML(item.description)
        return TodoItem(
            text: item.title,
            description: plainDescription,
            adoWorkItemId: String(item.id)
        )
    }

    // MARK: - Private

    private func stripHTML(_ html: String) -> String {
        guard !html.isEmpty else { return html }
        guard let data = html.data(using: .utf8) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Fallback: basic tag stripping
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
