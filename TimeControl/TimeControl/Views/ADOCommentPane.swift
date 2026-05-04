//
//  ADOCommentPane.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct ADOCommentPane: View {
    @ObservedObject var vm: ADOCommentViewModel

    var body: some View {
        switch vm.phase {
        case .idle:
            idleButton
        case .open, .sending:
            composeView
        case .sent:
            sentBanner
        case .queued:
            queuedBanner
        case .error:
            errorBanner
        }
    }

    // MARK: - Idle

    private var idleButton: some View {
        Button(action: vm.open) {
            Label("Add comment", systemImage: "bubble.left")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compose

    private var composeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            MentionAwareEditor(text: $vm.commentText, vm: vm)
                .frame(minHeight: 48, maxHeight: 100)
                .disabled(vm.phase == .sending)
                .opacity(vm.phase == .sending ? 0.6 : 1)

            if vm.mentionQuery != nil {
                MentionDropdown(vm: vm)
            }

            HStack {
                Button("Cancel", action: vm.cancel)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .disabled(vm.phase == .sending)

                Spacer()

                Button(action: { Task { await vm.send() } }) {
                    if vm.phase == .sending {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("Sending…")
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Send")
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.subheadline)
                .fontWeight(.medium)
                .disabled(vm.commentText.trimmingCharacters(in: .whitespaces).isEmpty || vm.phase == .sending || vm.mentionQuery != nil)
                .opacity((vm.commentText.trimmingCharacters(in: .whitespaces).isEmpty || vm.phase == .sending || vm.mentionQuery != nil) ? 0.4 : 1)
            }
        }
    }

    // MARK: - Sent

    private var sentBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
            Text("Comment sent")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: vm.dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Queued

    private var queuedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
                .font(.subheadline)
            Text("Queued — offline")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: vm.dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Error

    private var errorBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
            Text("Failed to send")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button("Retry") { Task { await vm.retry() } }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.subheadline)
            Button(action: vm.dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - NSViewRepresentable text editor with mention key interception

private struct MentionAwareEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var vm: ADOCommentViewModel

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MentionTextView()
        textView.mentionKeyHandler = context.coordinator.handleKey(event:)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderWidth = 0.5
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MentionTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = !context.coordinator.parent.vm.phase.isSending
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MentionAwareEditor

        init(_ parent: MentionAwareEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let newText = tv.string
            parent.text = newText
            parent.vm.handleTextChange(newText)
        }

        // keyDown is always called on the main thread, so MainActor.assumeIsolated is safe here.
        func handleKey(event: NSEvent) -> Bool {
            MainActor.assumeIsolated {
                guard parent.vm.mentionQuery != nil else { return false }
                switch event.keyCode {
                case 125: // down arrow
                    parent.vm.mentionMoveDown()
                    return true
                case 126: // up arrow
                    parent.vm.mentionMoveUp()
                    return true
                case 36, 76: // return / numpad enter
                    let idx = parent.vm.mentionSelectedIndex
                    guard idx < parent.vm.mentionResults.count else { return false }
                    parent.vm.selectMention(parent.vm.mentionResults[idx])
                    return true
                default:
                    return false
                }
            }
        }
    }
}

private class MentionTextView: NSTextView {
    var mentionKeyHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if mentionKeyHandler?(event) == true { return }
        super.keyDown(with: event)
    }
}

private extension ADOCommentViewModel.Phase {
    var isSending: Bool { self == .sending }
}
