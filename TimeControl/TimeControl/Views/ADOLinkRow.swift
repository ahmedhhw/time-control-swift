//
//  ADOLinkRow.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct ADOLinkRow: View {
    let workItemId: String
    private let urlBuilder = ADOURLBuilder()

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
                Button("Copy URL") {
                    if let url {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(url.absoluteString, forType: .string)
                    }
                }
                .disabled(url == nil)
            }

            Spacer()

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
}
