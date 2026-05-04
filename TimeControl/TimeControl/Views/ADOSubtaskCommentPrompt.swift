//
//  ADOSubtaskCommentPrompt.swift
//  TimeControl
//

import SwiftUI

struct ADOSubtaskCommentPrompt: View {
    let subtaskTitle: String
    let onYes: () -> Void
    let onNo: () -> Void
    let onAlways: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Post to ADO?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button("Yes", action: onYes)
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.subheadline)
            Button("No", action: onNo)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.subheadline)
            Button("Always", action: onAlways)
                .buttonStyle(.plain)
                .foregroundColor(.green)
                .font(.subheadline)
        }
    }
}
