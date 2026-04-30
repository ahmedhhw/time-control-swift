//
//  ADOSettingsSection.swift
//  TimeControl
//

import SwiftUI

struct ADOSettingsSection: View {

    private let settingsStore = ADOSettingsStore()

    @State private var showingPATSheet = false
    @State private var hasPAT: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Azure DevOps")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Optional. Connect to Azure DevOps to fetch work items into TimeControl.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button(hasPAT ? "Update ADO PAT" : "Set ADO PAT") {
                    showingPATSheet = true
                }

                if hasPAT {
                    Label("Token saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                } else {
                    Text("Not configured")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .onAppear { hasPAT = !settingsStore.pat.isEmpty }
        .sheet(isPresented: $showingPATSheet, onDismiss: {
            hasPAT = !settingsStore.pat.isEmpty
        }) {
            ADOPATSheet()
        }
    }
}

private struct ADOPATSheet: View {

    private let settingsStore = ADOSettingsStore()

    @Environment(\.dismiss) private var dismiss

    @State private var organization: String = ""
    @State private var project: String = ""
    @State private var pat: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Azure DevOps Connection").font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Enter your Azure DevOps organization, project, and a Personal Access Token. The token is stored locally in app preferences.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("Organization").gridColumnAlignment(.trailing)
                            TextField("e.g. contoso", text: $organization)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: organization) { _ in settingsStore.organization = organization }
                        }
                        GridRow {
                            Text("Project").gridColumnAlignment(.trailing)
                            TextField("e.g. my-project", text: $project)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: project) { _ in settingsStore.project = project }
                        }
                        GridRow {
                            Text("Personal Access Token").gridColumnAlignment(.trailing)
                            HStack(spacing: 8) {
                                SecureField("Paste your PAT", text: $pat)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: pat) { _ in savePAT() }
                                Button("Clear Token") { clearPAT() }
                                    .disabled(pat.isEmpty)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 500, minHeight: 280)
        .onAppear { loadStoredValues() }
    }

    // MARK: - Private

    private func loadStoredValues() {
        organization = settingsStore.organization
        project = settingsStore.project
        pat = settingsStore.pat
    }

    private func savePAT() {
        settingsStore.pat = pat
    }

    private func clearPAT() {
        pat = ""
        settingsStore.pat = ""
    }
}
