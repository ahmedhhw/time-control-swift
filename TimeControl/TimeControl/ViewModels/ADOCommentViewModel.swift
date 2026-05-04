//
//  ADOCommentViewModel.swift
//  TimeControl
//

import Foundation

@MainActor
final class ADOCommentViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case open
        case sending
        case sent
        case queued
        case error
    }

    @Published var phase: Phase = .idle
    @Published var commentText: String = ""

    let workItemId: String
    private let service: ADOService
    private let settings: ADOSettingsStore

    init(workItemId: String, service: ADOService = ADOService(), settings: ADOSettingsStore = ADOSettingsStore()) {
        self.workItemId = workItemId
        self.service = service
        self.settings = settings
    }

    func open() {
        phase = .open
    }

    func cancel() {
        commentText = ""
        phase = .idle
    }

    func send() async {
        guard !commentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let id = Int(workItemId) else { return }
        phase = .sending
        do {
            try await service.postComment(
                org: settings.organization,
                project: settings.project,
                id: id,
                comment: commentText,
                pat: settings.pat
            )
            commentText = ""
            phase = .sent
        } catch ADOService.ADOError.urlError, ADOService.ADOError.networkUnavailable, ADOService.ADOError.tlsError {
            phase = .queued
        } catch {
            phase = .error
        }
    }

    func retry() async {
        await send()
    }

    func dismiss() {
        commentText = ""
        phase = .idle
    }
}
