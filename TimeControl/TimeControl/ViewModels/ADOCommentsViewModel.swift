//
//  ADOCommentsViewModel.swift
//  TimeControl
//

import Foundation

@MainActor
final class ADOCommentsViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case loaded([ADOComment])
        case error(String)
    }

    @Published var state: State = .idle

    private(set) var workItemId: String
    private let service: ADOService
    private let settings: ADOSettingsStore

    init(workItemId: String, service: ADOService = ADOService(), settings: ADOSettingsStore = ADOSettingsStore()) {
        self.workItemId = workItemId
        self.service = service
        self.settings = settings
    }

    func updateWorkItemId(_ newId: String) async {
        guard newId != workItemId else { return }
        workItemId = newId
        state = .idle
        await fetch()
    }

    func fetch() async {
        guard let id = Int(workItemId) else {
            state = .error("Invalid work item ID")
            return
        }
        state = .loading
        do {
            let comments = try await service.fetchComments(
                org: settings.organization,
                project: settings.project,
                id: id,
                pat: settings.pat
            )
            state = .loaded(comments)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        await fetch()
    }
}
