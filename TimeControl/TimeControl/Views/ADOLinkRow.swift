//
//  ADOLinkRow.swift
//  TimeControl
//

import SwiftUI
import AppKit

// MARK: - ADOChip

/// Compact inline badge used in task rows to indicate an ADO-linked task.
struct ADOChip: View {
    let workItemId: String
    private let urlBuilder = ADOURLBuilder()

    private var url: URL? { urlBuilder.buildURL(id: workItemId) }

    var body: some View {
        Button(action: openURL) {
            Text("ADO #\(workItemId)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(url == nil ? .secondary : Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .help(url == nil ? "Configure ADO org & project in Settings to open in browser" : "Open ADO #\(workItemId) in browser")
        .contextMenu {
            if let url {
                Button("Open in Browser") { NSWorkspace.shared.open(url) }
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }
        }
    }

    private func openURL() {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

struct ADOLinkRow: View {
    let workItemId: String
    private let urlBuilder = ADOURLBuilder()
    @State private var copied = false

    private var url: URL? { urlBuilder.buildURL(id: workItemId) }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundColor(.secondary)
                .font(.caption)

            Button(action: openURL) {
                Text("ADO #\(workItemId)")
                    .font(.callout)
                    .foregroundColor(url == nil ? .secondary : .accentColor)
                    .underline(url != nil)
            }
            .buttonStyle(.plain)
            .disabled(url == nil)
            .contextMenu {
                Button("Copy URL") { copyURL() }
                    .disabled(url == nil)
            }

            Spacer()

            Button(action: copyID) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(copied ? "Copied!" : "Copy #\(workItemId)")

            Button(action: openURL) {
                HStack(spacing: 2) {
                    Text("Open")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(url == nil)
            .help(url == nil ? "Configure ADO organization & project in Settings" : "Open in browser")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func openURL() {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyID() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(workItemId, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }

    private func copyURL() {
        guard let url else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
    }
}
