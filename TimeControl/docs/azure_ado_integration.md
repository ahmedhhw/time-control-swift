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

## Authentication

**Recommended for this app: Personal Access Token (PAT)**

1. In ADO → User Settings → Personal Access Tokens
2. Create a token with scope: **Work Items (Read & Write)**
3. Store the token in macOS Keychain (never hardcode it)
4. Pass as Basic auth: `base64(":<PAT>")`

Swift usage:
```swift
let pat = "<your-pat>"
let credentials = Data(":\(pat)".utf8).base64EncodedString()
request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
```

---

## Implementation Plan

### 1. ADO Service Layer (`Services/ADOService.swift`)
- `createWorkItem(from task: TodoItem) async throws -> Int` — returns ADO work item ID
- `updateWorkItemState(id: Int, done: Bool) async throws`
- `updateTargetDate(id: Int, date: Date) async throws`
- PAT loaded from Keychain; org/project URL stored in `UserDefaults`

### 2. Model Changes
- Add `adoWorkItemId: Int?` to `TodoItem` — links a local task to its ADO counterpart
- Add `adoWorkItemId: Int?` to `Subtask` — for subtask-level ADO tasks (optional)

### 3. ViewModel Hooks (in `TodoViewModel`)
- After `addTodo(...)` → call `ADOService.createWorkItem(...)`, store returned ID
- In `toggleSubtask(_:in:)` when subtask flips to complete → call `ADOService.updateWorkItemState(...)`
- In the due date setter → call `ADOService.updateTargetDate(...)`
- All ADO calls should be fire-and-forget `Task { }` — don't block UI

### 4. Settings UI
- A settings pane (or sheet) to enter ADO org URL, project name, and PAT
- Toggle: "Sync tasks to ADO" (per-task or global)

---

## Effort Estimate

| Phase | Effort |
|---|---|
| ADOService networking layer | ~1–2 hours |
| Model + persistence changes | ~30 min |
| ViewModel hook-up | ~1 hour |
| Keychain PAT storage | ~30 min |
| Settings UI | ~1–2 hours |
| **Total** | **~4–6 hours** |

---

## Risks & Considerations

- **ADO field names vary by process template** (Agile vs Scrum vs CMMI). Confirm your org's work item type and field names before coding.
- **Subtask mapping**: ADO has child work items (parent-child links). Decide if TimeControl subtasks should become ADO child tasks or just fields on the parent.
- **Conflict resolution**: If someone edits the ADO item directly, TimeControl won't know. Keep sync one-directional (TimeControl → ADO) to start.
- **Rate limits**: ADO has soft throttling. Batch updates (`/$batch` endpoint) help if syncing many items at once.
