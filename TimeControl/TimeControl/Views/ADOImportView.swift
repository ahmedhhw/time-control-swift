//
//  ADOImportView.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct ADOImportView: View {

    /// Called when the user confirms the import. Receives the ready-to-add TodoItem.
    let onImport: (TodoItem) -> Void
    let onCancel: () -> Void

    @StateObject private var vm = ADOImportViewModel()
    @FocusState private var idFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 500, minHeight: 340)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                idFieldFocused = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Text("Import from Azure DevOps")
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Button("Import") {
                if let todo = vm.importAsNewTask() {
                    onImport(todo)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.fetchedItem == nil)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Main content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                idInputRow
                Divider()
                resultArea
            }
            .padding()
        }
    }

    // MARK: - ID input row

    private var idInputRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work Item ID or URL")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("e.g. 12345 or paste full URL", text: $vm.workItemIdText)
                    .textFieldStyle(.roundedBorder)
                    .focused($idFieldFocused)
                    .onSubmit { Task { await vm.fetchWorkItem() } }

                Button(action: { Task { await vm.fetchWorkItem() } }) {
                    if vm.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Fetch")
                            .frame(width: 60)
                    }
                }
                .disabled(!vm.canFetch || vm.isLoading)
            }

            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !vm.canFetch && !vm.workItemIdText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Configure your ADO organization, project, and PAT in Settings first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Result area

    @ViewBuilder
    private var resultArea: some View {
        if let item = vm.fetchedItem {
            VStack(alignment: .leading, spacing: 12) {
                Label("Found work item", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(item.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                if !item.description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (preview):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HTMLPreview(html: item.description)
                            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 160, alignment: .topLeading)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        } else if !vm.isLoading && vm.errorMessage == nil {
            Text("Enter a work item ID above and tap Fetch.")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
}

// MARK: - HTMLPreview

/// Renders HTML as plain text (strips tags). For Phase 1 simplicity.
private struct HTMLPreview: View {
    let html: String

    private var plainText: String {
        guard let data = html.data(using: .utf8) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            Text(plainText)
                .font(.callout)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
