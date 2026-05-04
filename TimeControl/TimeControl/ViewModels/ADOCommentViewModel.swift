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

    // Mention state
    @Published var mentionQuery: String? = nil
    @Published var mentionResults: [ADOUser] = []
    @Published var mentionIsLoading: Bool = false
    @Published var mentionSelectedIndex: Int = 0
    private var mentionTokens: [MentionToken] = []
    private var mentionSearchTask: Task<Void, Never>? = nil

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
        clearMentionState()
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
                comment: serialiseComment(),
                pat: settings.pat
            )
            commentText = ""
            mentionTokens = []
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
        clearMentionState()
        phase = .idle
    }

    // MARK: - Mention handling

    func handleTextChange(_ newText: String) {
        guard let atRange = findActiveMentionRange(in: newText) else {
            if mentionQuery != nil { clearMentionState() }
            return
        }
        let query = String(newText[atRange])
        if query != mentionQuery {
            mentionQuery = query
            mentionSelectedIndex = 0
            scheduleMentionSearch(query)
        }
    }

    func selectMention(_ user: ADOUser) {
        guard let query = mentionQuery else { return }
        let token = "@\(query)"
        let replacement = "@{\(user.displayName)} "
        if let range = commentText.range(of: token, options: .backwards) {
            commentText.replaceSubrange(range, with: replacement)
        }
        mentionTokens.append(MentionToken(displayName: user.displayName, descriptor: user.id))
        clearMentionState()
    }

    func mentionMoveUp() {
        guard !mentionResults.isEmpty else { return }
        mentionSelectedIndex = max(0, mentionSelectedIndex - 1)
    }

    func mentionMoveDown() {
        guard !mentionResults.isEmpty else { return }
        mentionSelectedIndex = min(mentionResults.count - 1, mentionSelectedIndex + 1)
    }

    // MARK: - Private

    private func findActiveMentionRange(in text: String) -> Range<String.Index>? {
        // Find the last @ that is preceded by start-of-string or whitespace,
        // and not yet followed by a closing brace (i.e. not a completed token).
        var searchFrom = text.endIndex
        while searchFrom > text.startIndex {
            let idx = text.index(before: searchFrom)
            if text[idx] == "@" {
                let before = idx == text.startIndex ? nil : text[text.index(before: idx)]
                let isPrecededByWhitespaceOrStart = before == nil || before!.isWhitespace
                if isPrecededByWhitespaceOrStart {
                    // Extract query from after @ to end of text (stop at next whitespace)
                    let queryStart = text.index(after: idx)
                    let queryEnd = text[queryStart...].firstIndex(where: { $0.isWhitespace }) ?? text.endIndex
                    // If the remaining text contains `{` it's already a completed token — skip
                    let candidate = String(text[queryStart..<queryEnd])
                    if !candidate.contains("{") {
                        return queryStart..<queryEnd
                    }
                }
            }
            searchFrom = idx
        }
        return nil
    }

    private func scheduleMentionSearch(_ query: String) {
        mentionSearchTask?.cancel()
        guard !query.isEmpty else {
            mentionResults = []
            mentionIsLoading = false
            return
        }
        mentionIsLoading = true
        mentionSearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let results = (try? await service.searchUsers(
                org: settings.organization,
                query: query,
                pat: settings.pat
            )) ?? []
            guard !Task.isCancelled else { return }
            mentionResults = results
            mentionIsLoading = false
        }
    }

    private func clearMentionState() {
        mentionSearchTask?.cancel()
        mentionSearchTask = nil
        mentionQuery = nil
        mentionResults = []
        mentionIsLoading = false
        mentionSelectedIndex = 0
    }

    private func serialiseComment() -> String {
        var result = commentText
        for token in mentionTokens {
            let placeholder = "@{\(token.displayName)}"
            let html = "<@mention user-id=\"\(token.descriptor)\">\(token.displayName)</@mention>"
            if let range = result.range(of: placeholder) {
                result.replaceSubrange(range, with: html)
            }
        }
        return result
    }
}
