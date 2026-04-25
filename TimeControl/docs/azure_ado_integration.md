# Azure ADO Integration

## Overview

Integrating TimeControl with Azure DevOps (ADO) is **low-to-moderate complexity**. The ADO REST API is well-documented and straightforward; the main effort is authentication setup and mapping TimeControl's data model to ADO work item fields.

---

## Target Features

| Feature | Complexity | Notes |
|---|---|---|
| Publish task to ADO | Low | Create a work item via POST |
| Update ADO when subtask completes | Low | PATCH work item state field |
| Sync due date → ADO target date | Low | PATCH work item date field |

---

## ADO REST API

**Base URL:** `https://dev.azure.com/{organization}/{project}/_apis/wit/`

### Create a Work Item (Task → ADO)
```
POST /workitems/$Task?api-version=7.1
Content-Type: application/json-patch+json

[
  { "op": "add", "path": "/fields/System.Title", "value": "Task name" },
  { "op": "add", "path": "/fields/Microsoft.VSTS.Scheduling.TargetDate", "value": "2026-05-01" }
]
```

### Update a Work Item (subtask complete, date change)
```
PATCH /workitems/{id}?api-version=7.1
Content-Type: application/json-patch+json

[
  { "op": "add", "path": "/fields/System.State", "value": "Done" }
]
```

For due date sync:
```
{ "op": "add", "path": "/fields/Microsoft.VSTS.Scheduling.TargetDate", "value": "2026-05-15" }
```

---

## Authentication — Personal Access Token (PAT)

1. In ADO → User Settings → Personal Access Tokens
2. Create a token with scope: **Work Items (Read & Write)**
3. Store the token in macOS Keychain (never hardcode it)
4. Pass as Basic auth: `base64(":<PAT>")`

Swift usage:
```swift
let pat = try Keychain.read("ado.pat")
let credentials = Data(":\(pat)".utf8).base64EncodedString()
request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
```

PAT lifecycle:
- PATs expire (max 1 year). Surface a clear error in the UI on `401` so the user knows to rotate.
- Provide a "Test connection" button in Settings that does a `GET /_apis/projects?api-version=7.1` and reports success/failure.

---

## Zscaler + Corporate VPN Considerations

The target device runs **Zscaler** (TLS-inspecting proxy) and a **corporate VPN**. This materially affects networking design — plan for it from day one rather than retrofitting.

### 1. TLS Interception (the big one)
Zscaler terminates TLS and re-signs responses with its own internal root CA. A vanilla `URLSession` request to `dev.azure.com` will see a Zscaler-issued cert, not Microsoft's.

- **macOS System Keychain already trusts the Zscaler root** (IT pushes it via MDM). `URLSession` uses the system trust store by default, so standard requests **should just work** — no custom `URLSessionDelegate` needed.
- **Do NOT implement certificate pinning.** Pinning to Microsoft's cert will break the moment Zscaler inspects the connection. If pinning is ever required for security review, pin to the Zscaler root instead — but the simpler answer is: don't pin.
- If requests fail with `NSURLErrorServerCertificateUntrusted` (-1202), the Zscaler root is missing from the user's keychain → that's an IT/MDM issue, not an app bug. Surface a clear error message pointing them to IT.

### 2. Proxy Configuration
Zscaler typically configures itself as a system proxy (PAC file or explicit HTTP proxy).

- `URLSession` honors the macOS system proxy settings by default — no extra code needed.
- Don't hardcode `URLSessionConfiguration.connectionProxyDictionary`. Let the system resolve it.
- If you ever build a `URLSession` with `.ephemeral`, it still picks up system proxy — fine.

### 3. VPN Dependency
ADO access likely requires the corporate VPN to be connected (especially if the org uses **Azure DevOps Server** on-prem, or has IP-allowlisted dev.azure.com).

- Detect connectivity failures distinctly: `NSURLErrorNotConnectedToInternet`, `NSURLErrorCannotFindHost`, and timeouts likely mean VPN is down.
- Show a non-blocking banner: *"Can't reach ADO — check VPN connection."* Don't lose the user's local data or queued sync state.
- All ADO calls remain fire-and-forget; queue failed mutations and retry when connectivity returns (see Sync Queue below).

### 4. Latency and Timeouts
TLS inspection + VPN hop adds latency. A request that's 80ms direct can be 400–800ms through Zscaler+VPN.

- Set `URLRequest.timeoutInterval = 30` (default 60 is fine but explicit is better).
- Never block UI on ADO calls. Already in the plan (`Task { }`), keep it that way.

### 5. Sync Queue (new requirement driven by VPN flakiness)
Because the VPN can drop, design the ADO layer as an **outbound queue**, not direct calls:

- On task create / subtask complete / due date change: enqueue a `PendingADOOperation` (persisted to disk).
- A background worker drains the queue when network is reachable.
- On `401` → mark PAT invalid, stop draining, prompt user. On `5xx` / network errors → exponential backoff retry.
- This also handles the case where the user is offline (laptop closed, on a plane, etc).

---

## Implementation Plan

### 1. ADO Service Layer (`Services/ADOService.swift`)
- `createWorkItem(from task: TodoItem) async throws -> Int` — returns ADO work item ID
- `updateWorkItemState(id: Int, done: Bool) async throws`
- `updateTargetDate(id: Int, date: Date) async throws`
- PAT loaded from Keychain; org/project URL stored in `UserDefaults`
- Use the default `URLSession.shared` so system trust store + system proxy are honored (Zscaler-friendly)

### 2. Sync Queue (`Services/ADOSyncQueue.swift`)
- `PendingADOOperation` enum (createTask / updateState / updateDate) persisted to disk
- Drains in background when reachable; exponential backoff on transient failures
- Pauses on `401` and surfaces a "PAT expired or invalid" banner
- Uses `NWPathMonitor` to detect reachability changes (VPN up/down)

### 3. Model Changes
- Add `adoWorkItemId: Int?` to `TodoItem` — links a local task to its ADO counterpart
- Add `adoWorkItemId: Int?` to `Subtask` — for subtask-level ADO tasks (optional)

### 4. ViewModel Hooks (in `TodoViewModel`)
- After `addTodo(...)` → enqueue `createTask` op
- In `toggleSubtask(_:in:)` when subtask flips to complete → enqueue `updateState` op
- In the due date setter → enqueue `updateDate` op
- ViewModel never awaits ADO directly — only enqueues

### 5. Settings UI
- A settings pane (or sheet) to enter ADO org URL, project name, and PAT
- "Test connection" button (calls `GET /_apis/projects`)
- Toggle: "Sync tasks to ADO" (per-task or global)
- Status indicator: queue depth + last sync time + VPN/network state

---

## Phase 1 — Connectivity Proof (auth + read-only fetch)

Before building any sync logic, prove end-to-end connectivity through Zscaler + VPN with a minimal slice. No models change, no queue, no writes.

### Scope
- Settings sheet with three text fields: **Organization**, **Project**, **Work Item ID**, plus a secure field for **PAT** (stored in Keychain).
- A "Fetch" button that hits ADO and displays the work item's `System.Title` and `System.Description` in the UI.
- That's it — read-only, single item, manual trigger.

### Endpoint
```
GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?fields=System.Title,System.Description&api-version=7.1
Authorization: Basic base64(":<PAT>")
```

Response (relevant fields):
```json
{
  "id": 12345,
  "fields": {
    "System.Title": "...",
    "System.Description": "..."
  }
}
```

Note: `System.Description` is HTML. For Phase 1, render it as plain text (strip tags) or drop it into a `WebView` — don't over-invest.

### Files to add
- `Services/ADOService.swift` — single method `fetchWorkItem(id: Int) async throws -> ADOWorkItem`
- `Services/Keychain.swift` — minimal read/write for the PAT
- `Views/ADOSettingsView.swift` — the settings sheet
- `Views/ADOFetchView.swift` (or inline in settings) — input ID + display result

### Acceptance criteria
- On the target device (Zscaler + VPN active), entering valid org/project/PAT and a known work item ID displays its title and description.
- A wrong PAT shows "Authentication failed (401)".
- VPN disconnected shows "Can't reach ADO — check VPN connection."
- A bad cert / missing Zscaler root shows "TLS error — contact IT to install the corporate root certificate."

### Out of scope for Phase 1
- Linking ADO items to local `TodoItem`s
- Any writes (create/update/state changes)
- Sync queue, reachability monitoring, retry logic
- Subtask mapping

### Effort
~2–3 hours total — most of the value is shaking out Zscaler/VPN/PAT issues before committing to the full design.

---

## Effort Estimate

| Phase | Effort |
|---|---|
| ADOService networking layer | ~1–2 hours |
| Sync queue + reachability (NWPathMonitor) | ~2–3 hours |
| Model + persistence changes | ~30 min |
| ViewModel hook-up | ~1 hour |
| Keychain PAT storage | ~30 min |
| Settings UI + Test Connection + status banner | ~2 hours |
| **Total** | **~7–9 hours** |

---

## Risks & Considerations

- **ADO field names vary by process template** (Agile vs Scrum vs CMMI). Confirm your org's work item type and field names before coding.
- **Subtask mapping**: ADO has child work items (parent-child links). Decide if TimeControl subtasks should become ADO child tasks or just fields on the parent.
- **Conflict resolution**: If someone edits the ADO item directly, TimeControl won't know. Keep sync one-directional (TimeControl → ADO) to start.
- **Rate limits**: ADO has soft throttling. Batch updates (`/$batch` endpoint) help if syncing many items at once.
