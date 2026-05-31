//
//  ADOImportView.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct ADOImportView: View {

    /// Called when the user confirms the import. Receives the ready-to-add TodoItems.
    let onImport: ([TodoItem]) -> Void
    let onCancel: () -> Void
    let existingAdoIds: Set<String>

    @StateObject private var vm = ADOImportViewModel()
    @FocusState private var idFieldFocused: Bool

    init(existingAdoIds: Set<String> = [], onImport: @escaping ([TodoItem]) -> Void, onCancel: @escaping () -> Void) {
        self.existingAdoIds = existingAdoIds
        self.onImport = onImport
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 520, minHeight: 460)
        .task {
            async let assigned: () = vm.loadAssigned()
            async let mentioned: () = vm.loadMentioned()
            _ = await (assigned, mentioned)
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
                let todos = vm.importSelected(existingAdoIds: existingAdoIds)
                onImport(todos)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canImport)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var canImport: Bool {
        let hasSelectedNewItems = vm.selectedIds.contains { !existingAdoIds.contains(String($0)) }
        let hasNewFetchedItem = vm.fetchedItem.map { !existingAdoIds.contains(String($0.id)) } ?? false
        return hasSelectedNewItems || hasNewFetchedItem
    }

    // MARK: - Main content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                assignedSection
                mentionedSection
                Divider()
                fetchByIdSection
            }
            .padding()
        }
    }

    // MARK: - Assigned section

    private var assignedSection: some View {
        let visibleAssignedItems = vm.assignedItems.filter { !existingAdoIds.contains(String($0.id)) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Assigned to me")
                    .font(.headline)
                Spacer()
                if vm.isLoadingAssigned {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Refresh") {
                        Task { await vm.loadAssigned() }
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                }
            }

            if let err = vm.assignedError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else if visibleAssignedItems.isEmpty && !vm.isLoadingAssigned {
                Text("No items")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ScrollView {
                    workItemList(visibleAssignedItems)
                }
                .frame(maxHeight: 240)
            }
        }
    }

    // MARK: - Mentioned section

    private var mentionedSection: some View {
        let visibleMentionedItems = vm.mentionedItems.filter { !existingAdoIds.contains(String($0.id)) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mentioned in")
                    .font(.headline)
                Spacer()
                if vm.isLoadingMentioned {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Refresh") {
                        Task { await vm.loadMentioned() }
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                }
            }

            if let err = vm.mentionedError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else if visibleMentionedItems.isEmpty && !vm.isLoadingMentioned {
                Text("No items")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                workItemList(visibleMentionedItems)
            }
        }
    }

    // MARK: - Work item row list

    @ViewBuilder
    private func workItemList(_ items: [ADOWorkItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.id) { item in
                workItemRow(item)
                if item.id != items.last?.id {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func workItemRow(_ item: ADOWorkItem) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { vm.selectedIds.contains(item.id) },
                set: { _ in vm.toggleSelection(item.id) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(item.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !item.state.isEmpty {
                        Text(item.state)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
                    }
                }
                Text(item.title)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.toggleSelection(item.id)
        }
    }

    // MARK: - Fetch by ID section

    private var fetchByIdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("or fetch by ID")
                .font(.subheadline)
                .foregroundColor(.secondary)

            idInputRow

            resultArea
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
            if existingAdoIds.contains(String(item.id)) {
                Text("Work item #\(item.id) is already added.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
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
            }
        } else if !vm.isLoading && vm.errorMessage == nil && !vm.workItemIdText.isEmpty {
            EmptyView()
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
