//
//  MentionDropdown.swift
//  TimeControl
//

import SwiftUI

struct MentionDropdown: View {
    @ObservedObject var vm: ADOCommentViewModel

    var body: some View {
        VStack(spacing: 0) {
            if vm.mentionIsLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Searching…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            } else if vm.mentionResults.isEmpty {
                Text(vm.mentionQuery?.isEmpty == true ? "Type to search…" : "No users found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(vm.mentionResults.enumerated()), id: \.element.id) { idx, user in
                    MentionRow(user: user, isSelected: idx == vm.mentionSelectedIndex)
                        .onTapGesture { vm.selectMention(user) }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
    }
}

private struct MentionRow: View {
    let user: ADOUser
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(user.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(.primary)
            Text(user.mailAddress)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
    }
}
