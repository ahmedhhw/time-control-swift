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

    @Published var assignedItems: [ADOWorkItem] = []
    @Published var mentionedItems: [ADOWorkItem] = []
    @Published var selectedIds: Set<Int> = []
    @Published var isLoadingAssigned: Bool = false
    @Published var isLoadingMentioned: Bool = false
    @Published var assignedError: String?
    @Published var mentionedError: String?

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

    // MARK: - Bulk load

    private static let ignoredStates: Set<String> = ["Removed", "Closed", "Resolved"]

    func loadAssigned() async {
        isLoadingAssigned = true
        assignedError = nil
        do {
            let items = try await service.fetchAssignedWorkItems(
                org: settings.organization,
                project: settings.project,
                pat: settings.pat
            )
            assignedItems = items.filter { !Self.ignoredStates.contains($0.state) }
        } catch {
            assignedError = errorDescription(for: error)
            assignedItems = []
        }
        isLoadingAssigned = false
    }

    func loadMentioned() async {
        isLoadingMentioned = true
        mentionedError = nil
        do {
            let items = try await service.fetchMentionedWorkItems(
                org: settings.organization,
                project: settings.project,
                pat: settings.pat
            )
            mentionedItems = items.filter { !Self.ignoredStates.contains($0.state) }
        } catch {
            mentionedError = errorDescription(for: error)
            mentionedItems = []
        }
        isLoadingMentioned = false
    }

    // MARK: - Selection

    func toggleSelection(_ id: Int) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    var canImport: Bool {
        !selectedIds.isEmpty || fetchedItem != nil
    }

    // MARK: - Import

    func importSelected(existingAdoIds: Set<String>) -> [TodoItem] {
        var result: [TodoItem] = []

        let allBulkItems = assignedItems + mentionedItems
        for id in selectedIds {
            let idString = String(id)
            guard !existingAdoIds.contains(idString) else { continue }
            guard let item = allBulkItems.first(where: { $0.id == id }) else { continue }
            result.append(TodoItem(
                text: item.title,
                description: stripHTML(item.description),
                adoWorkItemId: idString
            ))
        }

        if let item = fetchedItem {
            let idString = String(item.id)
            if !existingAdoIds.contains(idString) && !selectedIds.contains(item.id) {
                result.append(TodoItem(
                    text: item.title,
                    description: stripHTML(item.description),
                    adoWorkItemId: idString
                ))
            }
        }

        return result
    }

    // MARK: - Private

    private func errorDescription(for error: Error) -> String {
        guard let adoError = error as? ADOService.ADOError else {
            return "Unexpected error: \(error.localizedDescription)"
        }
        switch adoError {
        case .unauthorized:
            return "Authentication failed (401) — check your PAT in Settings."
        case .networkUnavailable:
            return "Can't reach ADO — check your network connection."
        case .tlsError:
            return "TLS error — if on a corporate network, contact IT."
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .urlError(let code):
            return "Network error (URLError \(code)) — check your connection."
        case .notFound:
            return "Work item not found."
        case .invalidResponse:
            return "Invalid response from ADO."
        }
    }

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
