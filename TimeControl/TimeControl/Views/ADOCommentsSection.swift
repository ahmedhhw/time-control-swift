//
//  ADOCommentsSection.swift
//  TimeControl
//

import SwiftUI

struct ADOCommentsSection: View {
    @ObservedObject var vm: ADOCommentsViewModel
    @State private var isExpanded: Bool = false

    private var headerTitle: String {
        if case .loaded(let comments) = vm.state {
            return "Comments (\(comments.count))"
        }
        return "Comments"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()

            HStack(spacing: 4) {
                Button(action: {
                    withAnimation { toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(headerTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { Task { await vm.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh comments")
            }

            if isExpanded {
                contentBody
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch vm.state {
        case .idle, .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

        case .error(let message):
            HStack(spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Retry") { Task { await vm.refresh() } }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            .padding(.vertical, 4)

        case .loaded(let comments):
            if comments.isEmpty {
                Text("No comments yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(comment.authorDisplayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("·")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(comment.relativeTimeString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(comment.text)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)

                        if index < comments.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func toggle() {
        isExpanded.toggle()
        if isExpanded, case .idle = vm.state {
            Task { await vm.fetch() }
        }
    }
}
