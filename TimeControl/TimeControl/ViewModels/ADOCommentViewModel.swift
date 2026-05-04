//
//  ADOCommentViewModel.swift
//  TimeControl
//

import AppKit
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

    static let defaultTypingAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
        .foregroundColor: NSColor.textColor,
    ]

    @Published var phase: Phase = .idle
    @Published var commentBody = NSMutableAttributedString()
    @Published var pastedImages: [PastedImage] = []

    /// Plain-text projection for tests and prefilled sends (setting replaces `commentBody` with attributed plain text).
    var commentText: String {
        get { commentBody.string }
        set {
            commentBody = NSMutableAttributedString(string: newValue, attributes: Self.defaultTypingAttributes)
        }
    }

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
        commentBody = NSMutableAttributedString()
        pastedImages = []
        clearMentionState()
        phase = .idle
    }

    func send() async {
        let hasText = !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasText || !pastedImages.isEmpty else { return }
        guard let id = Int(workItemId) else { return }
        phase = .sending
        if mentionTokens.contains(where: { $0.storageKey == nil }) {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
        // Upload each pending image sequentially
        for index in pastedImages.indices {
            guard pastedImages[index].uploadState == .pending else { continue }
            pastedImages[index].uploadState = .uploading
            do {
                let url = try await service.uploadAttachment(
                    org: settings.organization,
                    project: settings.project,
                    filename: pastedImages[index].filename,
                    data: pastedImages[index].data,
                    pat: settings.pat
                )
                pastedImages[index].uploadState = .uploaded(url)
            } catch {
                pastedImages[index].uploadState = .failed
            }
        }
        let anyFailed = pastedImages.contains { $0.uploadState == .failed }
        do {
            try await service.postComment(
                org: settings.organization,
                project: settings.project,
                id: id,
                comment: serialiseComment(),
                pat: settings.pat
            )
            commentBody = NSMutableAttributedString()
            mentionTokens = []
            if !anyFailed {
                pastedImages = []
            }
            phase = .sent
        } catch ADOService.ADOError.urlError, ADOService.ADOError.networkUnavailable, ADOService.ADOError.tlsError {
            phase = .queued
        } catch {
            phase = .error
        }
    }

    @discardableResult
    func pasteImage(_ data: Data, filename: String) -> UUID {
        let id = UUID()
        pastedImages.append(PastedImage(id: id, filename: filename, data: data, uploadState: .pending))
        return id
    }

    func removeImage(id: UUID) {
        pastedImages.removeAll { $0.id == id }
        let ms = NSMutableAttributedString(attributedString: commentBody)
        var ranges: [NSRange] = []
        ms.enumerateAttribute(.attachment, in: NSRange(location: 0, length: ms.length), options: [.reverse]) { value, range, _ in
            if let att = value as? InlineImageAttachment, att.pastedImageId == id {
                ranges.append(range)
            }
        }
        for r in ranges {
            ms.deleteCharacters(in: r)
        }
        commentBody = ms
    }

    func retry() async {
        await send()
    }

    func dismiss() {
        commentBody = NSMutableAttributedString()
        pastedImages = []
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
        let full = commentBody.string
        guard let range = full.range(of: token, options: .backwards) else {
            clearMentionState()
            return
        }
        let nsRange = NSRange(range, in: full)
        let ms = NSMutableAttributedString(attributedString: commentBody)
        var eff = NSRange()
        let attrs = ms.attributes(at: nsRange.location, longestEffectiveRange: &eff, in: NSRange(location: 0, length: ms.length))
        let base = attrs.isEmpty ? Self.defaultTypingAttributes : attrs
        let rep = NSAttributedString(string: replacement, attributes: base)
        ms.replaceCharacters(in: nsRange, with: rep)
        commentBody = ms
        mentionTokens.append(MentionToken(displayName: user.displayName, descriptor: user.id, storageKey: nil))
        clearMentionState()
        Task { await resolveStorageKey(for: user) }
    }

    private func resolveStorageKey(for user: ADOUser) async {
        guard let key = try? await service.fetchStorageKey(org: settings.organization, descriptor: user.id, pat: settings.pat) else { return }
        if let idx = mentionTokens.firstIndex(where: { $0.descriptor == user.id }) {
            mentionTokens[idx].storageKey = key
        }
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
        let ns = commentBody.string as NSString
        let len = ns.length
        var i = 0
        var html = ""
        var referencedAttachmentIds = Set<UUID>()
        while i < len {
            if ns.character(at: i) == Self.objectReplacementUTF16 {
                var eff = NSRange(location: i, length: 1)
                let attrs = commentBody.attributes(at: i, effectiveRange: &eff)
                if let att = attrs[.attachment] as? InlineImageAttachment {
                    referencedAttachmentIds.insert(att.pastedImageId)
                    html += htmlForUploadedImage(id: att.pastedImageId)
                }
                i = eff.upperBound
            } else {
                let start = i
                i += 1
                while i < len && ns.character(at: i) != Self.objectReplacementUTF16 {
                    i += 1
                }
                let chunk = ns.substring(with: NSRange(location: start, length: i - start))
                html += serialisePlainTextChunk(chunk)
            }
        }
        // Pasted images without an inline attachment (e.g. unit tests) still append at the end.
        for img in pastedImages {
            guard case .uploaded(let url) = img.uploadState else { continue }
            if referencedAttachmentIds.contains(img.id) { continue }
            html += imgTag(url: url, filename: img.filename)
        }
        return html
    }

    /// UTF-16 for Unicode object replacement / attachment placeholder.
    private static let objectReplacementUTF16: unichar = 0xFFFC

    private func htmlForUploadedImage(id: UUID) -> String {
        guard let img = pastedImages.first(where: { $0.id == id }) else { return "" }
        switch img.uploadState {
        case .uploaded(let url):
            return imgTag(url: url, filename: img.filename)
        case .failed, .pending, .uploading:
            return ""
        }
    }

    private func imgTag(url: URL, filename: String) -> String {
        let src = escapeHtmlAttribute(url.absoluteString)
        let alt = escapeHtmlAttribute(filename)
        return "<img src=\"\(src)\" alt=\"\(alt)\"/>"
    }

    private func escapeHtmlAttribute(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func serialisePlainTextChunk(_ chunk: String) -> String {
        var result = chunk
        for token in mentionTokens {
            let placeholder = "@{\(token.displayName)}"
            let id = token.storageKey ?? token.descriptor
            let html = "<a href=\"#\" data-vss-mention=\"version:2.0,\(id)\">@\(token.displayName)</a>"
            if let range = result.range(of: placeholder) {
                result.replaceSubrange(range, with: html)
            }
        }
        result = result.replacingOccurrences(of: "\n", with: "<br>")
        result = linkify(result)
        return result
    }

    private func linkify(_ text: String) -> String {
        let segments = LinkParser.parse(text)
        return segments.map { segment in
            switch segment {
            case .text(let s): return s
            case .link(let url):
                let urlStr = url.absoluteString
                return "<a href=\"\(urlStr)\">\(urlStr)</a>"
            }
        }.joined()
    }
}
