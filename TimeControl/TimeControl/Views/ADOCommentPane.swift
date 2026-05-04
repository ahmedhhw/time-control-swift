//
//  ADOCommentPane.swift
//  TimeControl
//

import SwiftUI

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
            TextEditor(text: $vm.commentText)
                .font(.body)
                .frame(minHeight: 48, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .disabled(vm.phase == .sending)
                .opacity(vm.phase == .sending ? 0.6 : 1)
                .onChange(of: vm.commentText) { newValue in
                    vm.handleTextChange(newValue)
                }
                .onKeyPress(.upArrow) {
                    guard vm.mentionQuery != nil else { return .ignored }
                    vm.mentionMoveUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard vm.mentionQuery != nil else { return .ignored }
                    vm.mentionMoveDown()
                    return .handled
                }
                .onKeyPress(.return) {
                    guard vm.mentionQuery != nil,
                          vm.mentionSelectedIndex < vm.mentionResults.count else { return .ignored }
                    vm.selectMention(vm.mentionResults[vm.mentionSelectedIndex])
                    return .handled
                }

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
