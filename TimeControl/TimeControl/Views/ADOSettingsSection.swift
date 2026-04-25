//
//  ADOSettingsSection.swift
//  TimeControl
//

import SwiftUI

struct ADOSettingsSection: View {

    private let settingsStore = ADOSettingsStore()
    private let service = ADOService()

    @State private var organization: String = ""
    @State private var project: String = ""
    @State private var pat: String = ""
    @State private var workItemId: String = ""

    @State private var fetchedItem: ADOWorkItem?
    @State private var fetchError: String?
    @State private var isFetching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Azure DevOps")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Phase 1 — connectivity proof. Enter your credentials and a work item ID to verify the connection.")
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
                    SecureField("PAT (stored in Keychain)", text: $pat)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: pat) { _ in savePAT() }
                }
                GridRow {
                    Text("Work Item ID").gridColumnAlignment(.trailing)
                    TextField("e.g. 12345", text: $workItemId)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Button("Fetch Work Item") {
                    Task { await fetchItem() }
                }
                .disabled(isFetching || organization.isEmpty || project.isEmpty || pat.isEmpty || workItemId.isEmpty)

                if isFetching {
                    ProgressView().scaleEffect(0.7)
                }
            }

            if let item = fetchedItem {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                    Text(item.title).fontWeight(.medium)
                    if !item.description.isEmpty {
                        Text(item.description.strippingHTML())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            if let error = fetchError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
        }
        .onAppear { loadStoredValues() }
    }

    // MARK: - Private

    private func loadStoredValues() {
        organization = settingsStore.organization
        project = settingsStore.project
        pat = (try? Keychain.read("ado.pat")) ?? ""
    }

    private func savePAT() {
        guard !pat.isEmpty else { return }
        try? Keychain.save("ado.pat", value: pat)
    }

    private func fetchItem() async {
        guard let id = Int(workItemId) else {
            fetchError = "Work item ID must be a number."
            fetchedItem = nil
            return
        }
        isFetching = true
        fetchedItem = nil
        fetchError = nil

        do {
            let item = try await service.fetchWorkItem(org: organization, project: project, id: id, pat: pat)
            fetchedItem = item
        } catch ADOService.ADOError.unauthorized {
            fetchError = "Authentication failed (401) — check your PAT."
        } catch ADOService.ADOError.notFound {
            fetchError = "Work item \(id) not found — check org, project, and ID."
        } catch ADOService.ADOError.networkUnavailable {
            fetchError = "Can't reach ADO — check VPN connection."
        } catch ADOService.ADOError.invalidResponse {
            fetchError = "TLS error or unexpected response — contact IT to install the corporate root certificate."
        } catch {
            fetchError = error.localizedDescription
        }
        isFetching = false
    }
}

// MARK: - HTML stripping

private extension String {
    func strippingHTML() -> String {
        guard let data = data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil)
        else {
            return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        return attributed.string
    }
}
