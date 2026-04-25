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

## Proposal — Pull ADO item into a local TodoItem

Take what Phase 1 fetches and turn it into a real, time-trackable TodoItem in TimeControl. Still no writes back to ADO. This is where the integration starts being *useful* — you can pull a ticket assigned to you and start tracking time against it locally.

### Goals
- Replace the throwaway "Fetch" button in Settings with an "Import from ADO" flow inside the main app.
- Persist the ADO link on the local task: add `adoWorkItemId: Int?` to `TodoItem`.
- A task already imported from ADO shows a small badge (`ADO #12345`) next to its title.

### UI Mockup — Import dialog (triggered from "+" menu or a button in the toolbar)

```
┌─ Import from Azure DevOps ──────────────────────────┐
│                                                     │
│  Work Item ID:  ┌─────────────────┐                 │
│                 │ 12345           │  [ Fetch ]      │
│                 └─────────────────┘                 │
│                                                     │
│  ─────────────────────────────────────────────────  │
│                                                     │
│   ✓ Found work item                                 │
│                                                     │
│   #12345 · Bug · Active                             │
│   "Login button misaligned on Safari"               │
│                                                     │
│   Description (preview):                            │
│   ┌─────────────────────────────────────────────┐   │
│   │ The login button on the auth page shifts    │   │
│   │ 4px right on Safari 17+. Repro on macOS …   │   │
│   └─────────────────────────────────────────────┘   │
│                                                     │
│   Import as:  ◉ New task   ○ Subtask of …  ▾        │
│                                                     │
│              [ Cancel ]      [ Import ]             │
└─────────────────────────────────────────────────────┘
```

### UI Mockup — Imported task in the list

```
  ▸  ┌──────────────────────────────────────────────┐
     │ ▶  Login button misaligned on Safari         │
     │    [ ADO #12345 ]   ⏱ 0:00:00                │
     └──────────────────────────────────────────────┘
```

The `[ ADO #12345 ]` chip is clickable → opens `https://dev.azure.com/{org}/{project}/_workitems/edit/12345` in the browser.

### Out of scope
- Any writes back to ADO (state, dates, time)
- Re-syncing if the ADO item changes
- Browsing / searching ADO (you must know the ID)

### Effort
~2–3 hours.

---

## Proposal — Push completion state back to ADO

First write path. When you complete a task or subtask in TimeControl, the linked ADO work item state flips to `Done` (or whatever the closed state is for that work item type).

### Goals
- On `TodoItem.isCompleted = true` → PATCH ADO state to `Done`.
- On `Subtask.isCompleted = true` (only if the subtask itself has an `adoWorkItemId`) → same.
- Introduce the `ADOSyncQueue` here, even if minimally — a single failed PATCH must not be silently lost.
- Toast / inline confirmation when the ADO update succeeds.

### UI Mockup — Subtle status indicator next to the imported task

```
  ▸  ┌──────────────────────────────────────────────┐
     │ ✓  Login button misaligned on Safari         │
     │    [ ADO #12345 ]  ↑ Synced 2s ago           │
     └──────────────────────────────────────────────┘
```

States the chip can show:
```
  [ ADO #12345 ]  ↑ Synced 2s ago        ← success
  [ ADO #12345 ]  ⟳ Syncing…             ← in-flight
  [ ADO #12345 ]  ⚠ Queued (offline)     ← VPN down, will retry
  [ ADO #12345 ]  ✗ Sync failed          ← permanent error, click for detail
```

### UI Mockup — Persistent banner when PAT expires (queue paused)

```
┌────────────────────────────────────────────────────────────┐
│ ⚠ Azure DevOps token expired — 3 changes waiting to sync.  │
│    [ Update PAT in Settings ]                              │
└────────────────────────────────────────────────────────────┘
```

### Out of scope
- Pushing time tracked back to ADO (separate proposal)
- Pushing due-date / target-date changes (separate proposal)
- Two-way sync

### Effort
~3–4 hours (most of it goes into the queue + reachability).

---

## Proposal — Push due dates and create new ADO items

Round out the create / update path so that local task creation and due-date edits both flow upstream.

### Goals
- "Create in ADO" toggle on the new-task dialog. When on, the task is created locally *and* a corresponding ADO work item is created (queued) and linked.
- Editing a local task's due date PATCHes `Microsoft.VSTS.Scheduling.TargetDate`.
- Settings: a default work item type per project (Task / Bug / User Story), since `POST /workitems/$Task` is type-specific.

### UI Mockup — New-task dialog, ADO toggle visible

```
┌─ New Task ───────────────────────────────────────────┐
│                                                      │
│  Title:        ┌─────────────────────────────────┐   │
│                │ Refactor auth middleware        │   │
│                └─────────────────────────────────┘   │
│                                                      │
│  Due date:     [ 2026-05-15  ▾ ]                     │
│                                                      │
│  Estimated:    [ 4h  ▾ ]                             │
│                                                      │
│  ☑ Also create in Azure DevOps                       │
│       Type: [ Task ▾ ]   Project: backend-api        │
│                                                      │
│              [ Cancel ]        [ Create ]            │
└──────────────────────────────────────────────────────┘
```

### UI Mockup — Settings: ADO sync preferences

```
┌─ Azure DevOps ───────────────────────────────────────┐
│                                                      │
│  Organization:  contoso                              │
│  Project:       backend-api          [ Change ]      │
│  PAT:           ●●●●●●●●●●●●  (valid)  [ Update ]    │
│                                                      │
│  ─────────────────────────────────────────────────   │
│                                                      │
│  ☑ Auto-create ADO items for new tasks               │
│      Default type:  [ Task ▾ ]                       │
│                                                      │
│  ☑ Push due-date changes to ADO                      │
│  ☑ Push completion state to ADO                      │
│  ☐ Push tracked time to ADO                          │
│                                                      │
│  ─────────────────────────────────────────────────   │
│                                                      │
│  Sync queue:  0 pending · last sync 14s ago          │
│  Network:     ● VPN connected · ADO reachable        │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Out of scope
- Pulling ADO changes back (still one-way: TimeControl → ADO)
- Time tracking sync (separate proposal)

### Effort
~3 hours.

---

## Proposal — Push tracked time to ADO (optional)

Time tracked locally rolls up to ADO's `Microsoft.VSTS.Scheduling.CompletedWork` field. This is the most value but also the riskiest phase — it changes a numeric field that some teams use for reporting.

### Goals
- On task pause/complete: add the elapsed session duration (in hours) to `CompletedWork`.
- Idempotency: never double-count. The queue op carries a session UUID; if the queue is re-played, the server-side state is consulted first.
- A per-task "Don't sync time to ADO" override for tasks where tracking is local-only.

### UI Mockup — Time-sync indicator on the floating window

```
┌─ Current Task ───────────────────────────────────┐
│                                                  │
│   ▶  Login button misaligned on Safari           │
│      [ ADO #12345 ]                              │
│                                                  │
│      ⏱  1:24:36                                  │
│      ↑ ADO: 1:24:00 logged                       │
│                                                  │
│      ▾  Subtasks (2)                             │
│                                                  │
└──────────────────────────────────────────────────┘
```

When local time exceeds ADO-logged time by >1 minute, an unobtrusive "↑ pending" appears.

### Out of scope
- Bidirectional time sync (if someone edits CompletedWork directly in ADO)

### Effort
~2 hours.

---

## Proposal — Read-back and conflict surfacing (stretch)

Up to here, sync is one-way. Phase 6 introduces a periodic poll to detect when ADO has diverged: the work item was closed by someone else, the title changed, the assignee changed.

### Goals
- Poll linked work items every N minutes (default 10) when the app is foregrounded.
- If ADO state went to `Done` and the local task is still active, prompt: *"This ADO item was closed by someone else. Mark complete locally?"*
- If the title differs, show both inline and offer to overwrite local.

### UI Mockup — Conflict banner on the task

```
  ▸  ┌──────────────────────────────────────────────────┐
     │ ▶  Login button misaligned on Safari             │
     │    [ ADO #12345 ]   ⚠ Closed in ADO              │
     │    ──────────────────────────────────────────    │
     │    This work item was marked Done in ADO 2h ago. │
     │    [ Mark complete here ]   [ Reopen in ADO ]    │
     └──────────────────────────────────────────────────┘
```

### Out of scope
- Full bidirectional merge (description rich-text, comments, attachments). Not worth it for a single-user tracking app.

### Effort
~3–4 hours.

---

## Proposal — Link an existing local task to an ADO work item

You already have a local task (maybe you created it before the ADO integration existed, or it started as a quick note that became real work). You want to attach an ADO ID to it without rebuilding the task from scratch.

### Goals
- Right-click a task → "Link to ADO Work Item…"
- Dialog accepts a work item ID, fetches metadata, asks for confirmation, then writes `adoWorkItemId` onto the local task.
- Same dialog from the floating window's overflow menu.
- Unlink is just clearing the ID — no destructive prompt needed.

### UI Mockup — Right-click context menu

```
  ┌────────────────────────────────┐
  │  ▶  Login button misaligned    │ ← right-clicked
  │     ⏱ 0:00:00                  │
  └────────────────────────────────┘
       │
       └─┐
         ▼
   ┌─────────────────────────────┐
   │  Rename…                    │
   │  Set due date…              │
   │  ─────────────────────────  │
   │  Link to ADO Work Item…  ↗  │
   │  ─────────────────────────  │
   │  Delete                     │
   └─────────────────────────────┘
```

### UI Mockup — Link dialog (similar to import, but doesn't create a new task)

```
┌─ Link Task to Azure DevOps ────────────────────────┐
│                                                    │
│  Local task:  "Login button misaligned on Safari"  │
│                                                    │
│  ADO Work Item ID:  ┌─────────────┐  [ Verify ]    │
│                     │ 12345       │                │
│                     └─────────────┘                │
│                                                    │
│   ✓ #12345 · Bug · Active                          │
│     "Login bug — Safari rendering glitch"          │
│                                                    │
│   ⚠ The titles don't match exactly. Link anyway?   │
│                                                    │
│            [ Cancel ]      [ Link ]                │
└────────────────────────────────────────────────────┘
```

The title-mismatch warning is friendly but not blocking — it's common for the local task to drift in name.

### Effort
~1–2 hours (mostly UI; the underlying fetch already exists from Phase 1).

---

## Proposal — Push subtask completion as an ADO comment (with confirmation)

When a subtask is checked off, optionally drop a comment on the parent ADO work item like *"Subtask completed: Wire up retry button"*. This avoids polluting state changes (the parent isn't done yet) but gives ADO watchers a real-time activity feed.

### Goals
- After toggling a subtask to complete, show a small inline prompt: *"Push to ADO?"* with **Yes** / **No** / **Always for this task**.
- The comment is posted to ADO via `POST /workitems/{id}/comments` (note: comments use `?api-version=7.1-preview.4`).
- "Always" is sticky per task — stored in `TodoItem.adoAutoPushSubtasks: Bool`.
- Never block the UI on the network call; the comment goes through the sync queue.

### UI Mockup — Inline confirmation after subtask completion

```
  ▸  ┌──────────────────────────────────────────────┐
     │ ▶  Login button misaligned on Safari         │
     │    [ ADO #12345 ]                            │
     │                                              │
     │    ✓  Wire up retry button                   │ ← just completed
     │       ┌──────────────────────────────────┐   │
     │       │ Push to ADO as comment?          │   │
     │       │  [ Yes ]  [ No ]  [ Always ]     │   │
     │       └──────────────────────────────────┘   │
     │    ☐  Add error toast                        │
     │    ☐  Test on Safari TP                      │
     └──────────────────────────────────────────────┘
```

### UI Mockup — What lands in ADO

```
  Comment from TimeControl • 2 minutes ago
  ─────────────────────────────────────────
  ✓ Subtask completed: Wire up retry button
```

### Effort
~2 hours (1h queue op + comment endpoint, 1h UI prompt + per-task toggle).

---

## Proposal — Quick custom comment to current task's ADO

A persistent text field (or keyboard shortcut–opened popup) on the floating window that pushes whatever you type as a comment to the running task's ADO. Friction-free progress notes.

### Goals
- Keyboard shortcut (e.g. `⌘⇧K`) opens a single-line comment input.
- Disabled if the running task has no ADO link.
- Empty input does nothing; non-empty queues a `POST /comments` op.
- Inline confirmation: *"Sent to ADO #12345"* fades after 2s.

### UI Mockup — Comment popup (anchored to floating window)

```
┌─ Current Task ───────────────────────────────────┐
│   ▶  Login button misaligned on Safari           │
│      [ ADO #12345 ]   ⏱ 0:42:11                  │
│                                                  │
│      💬 Comment to ADO:  ⌘⇧K to focus            │
│      ┌─────────────────────────────────────────┐ │
│      │ Reproduced on Safari 17.4 — issue is in │ │
│      │ the flexbox shrink behavior, not pixel  │ │
│      │ rounding. Filing follow-up.             │ │
│      └─────────────────────────────────────────┘ │
│                              [ Send to ADO ]     │
└──────────────────────────────────────────────────┘
```

### UI Mockup — Confirmation toast

```
  ┌──────────────────────────────────────┐
  │  ✓ Sent to ADO #12345                │
  └──────────────────────────────────────┘
```

If the running task has no ADO link, the field is replaced with a hint:

```
  💬 Link this task to ADO to add comments.  [ Link… ]
```

### Effort
~1–2 hours.

---

## Proposal — At-a-glance ADO indicator on every task

Make ADO-linked tasks visually distinct in the main list and floating window without a full chip if space is tight. A single character / icon in the row gutter is enough.

### Goals
- A small ADO logo (or `◆`) in the leftmost gutter for every linked task.
- Tooltip on hover: *"ADO #12345 · Active"*.
- Right-click on the icon → "Open in ADO", "Unlink", "Refresh metadata".

### UI Mockup — Main task list with mixed linked / unlinked

```
  ◆  ▶  Login button misaligned on Safari       ⏱ 0:42
        Refactor auth middleware                ⏱ 1:03
  ◆     Migrate Postgres to v16                 ⏱ 0:00
        Quick fix: typo in login banner         ⏱ 0:05
  ◆  ▸  Investigate flaky CI tests              ⏱ 2:14
```

The `◆` is colored (Azure blue or similar) so it pops without being loud. Tasks without ADO have a blank gutter — the absence is itself the signal.

### UI Mockup — Hover tooltip

```
       ◆  ←─ hovering
       │
       ▼
   ┌──────────────────────────┐
   │ ADO #12345 · Bug · Active│
   │ "Login bug — Safari …"   │
   └──────────────────────────┘
```

### Effort
~1 hour (just a gutter view + tooltip; no new networking).

---

## Proposal — Optionally notify ADO when you start working on a task

Some teams want visibility into *who is actively working on what right now*. When you press play on a linked task, optionally flip the ADO state from `New` → `Active` and/or post a comment *"Started working — TimeControl"*.

### Goals
- Per-task setting: `adoNotifyOnStart: Bool` (default off, opt-in).
- Global default in Settings: *"When I start a task linked to ADO, automatically …"* with three options:
  - *Do nothing* (default)
  - *Set state to Active*
  - *Post a comment*
  - *Both*
- Only fires once per task per state-cycle (don't spam ADO every time you pause/resume).

### UI Mockup — Per-task override (in task detail / context menu)

```
   ┌─────────────────────────────────────────────┐
   │  ◆ Login button misaligned on Safari        │
   │    [ ADO #12345 ]                           │
   │                                             │
   │    On start:                                │
   │      ◉ Use global default (Do nothing)      │
   │      ○ Set ADO state to Active              │
   │      ○ Post "Started working" comment       │
   │      ○ Both                                 │
   │                                             │
   │    On complete:                             │
   │      ☑ Set ADO state to Done                │
   │      ☐ Post completion comment              │
   └─────────────────────────────────────────────┘
```

### UI Mockup — One-time confirmation on first start

```
┌────────────────────────────────────────────────────┐
│  Notify ADO that you started this task?            │
│                                                    │
│  [ Yes, just this once ]                           │
│  [ Yes, always for this task ]                     │
│  [ No ]                                            │
│  [ Never for any task ]  ← becomes the new default │
└────────────────────────────────────────────────────┘
```

### Effort
~2 hours.

---

## Proposal — Push elapsed time as a comment when a task completes

Different from the `CompletedWork` field push (separate proposal). This one writes a human-readable *comment* like *"Completed in 2h 14m (TimeControl)"* — useful for teams that don't formally use the time-tracking field but appreciate context in the activity log.

### Goals
- On `TodoItem.isCompleted = true`, if the task has an ADO link and `adoPushTimeAsComment` is on (per-task or global default), enqueue a `POST /comments` op.
- Comment format is configurable in Settings: include subtask breakdown? Include start/end timestamps? Default minimal.

### UI Mockup — What lands in ADO

```
  Comment from TimeControl • just now
  ───────────────────────────────────
  ✓ Task completed
  • Total time: 2h 14m
  • Sessions: 4 (across 2 days)
  • Subtasks completed: 3 of 3
```

### UI Mockup — Settings toggle

```
   ☑ Post completion summary to ADO as a comment
       Include:  ☑ Total time   ☑ Session count
                 ☑ Subtask summary   ☐ Per-session breakdown
```

### Effort
~1–2 hours.

---

## Proposal — Notifications for new comments on your ADO items

Pull-side feature, so it depends on the read-back proposal's polling infrastructure. When the poller sees a new comment on any linked work item where you're the assignee or the comment @-mentions you, surface it as a macOS notification.

### Goals
- Reuse the polling cadence from the read-back proposal (every N minutes).
- Track `lastSeenCommentId` per linked work item.
- Notification body: comment author + first ~120 chars. Click → opens the work item in browser.
- In-app inbox: a small badge on the linked task shows unread count.

### UI Mockup — macOS notification

```
  ┌──────────────────────────────────────────────────────┐
  │  TimeControl                              now        │
  │                                                      │
  │  💬 New comment on ADO #12345                        │
  │     Sarah Chen: "Confirmed the repro on Firefox      │
  │     too — bumping severity to High."                 │
  │                                                      │
  │  [ Reply ]   [ View in ADO ]   [ Dismiss ]           │
  └──────────────────────────────────────────────────────┘
```

`[ Reply ]` reuses the quick-comment popup from the proposal above, prefilled with `@SarahChen` if mentions are detected.

### UI Mockup — In-app badge on a task with unread comments

```
  ◆²  ▶  Login button misaligned on Safari      ⏱ 0:42
                                  └─ 2 unread comments
```

The superscript next to the `◆` is the unread count. Clicking it opens an inline drawer showing the comments inline (read-only).

### UI Mockup — Inline comment drawer (expanded)

```
  ▸  ┌──────────────────────────────────────────────────┐
     │ ◆² ▶  Login button misaligned on Safari          │
     │       [ ADO #12345 ]   ⏱ 0:42                    │
     │       ──────────────────────────────────────     │
     │       💬 Sarah Chen · 14m ago                    │
     │          "Confirmed the repro on Firefox too —   │
     │           bumping severity to High."             │
     │                                                  │
     │       💬 Marco Diaz · 6m ago                     │
     │          "Patch incoming, see PR #4921"          │
     │                                                  │
     │       [ Reply… ]    [ Mark all read ]            │
     └──────────────────────────────────────────────────┘
```

### Considerations
- Don't notify for comments *you* posted from TimeControl (filter by author).
- Quiet-hours / Do Not Disturb: respect macOS Focus modes (already handled by `UNUserNotificationCenter`).
- Polling cost: one `GET /comments` per linked task per cycle is fine for ~50 tasks; beyond that, batch via WIQL.

### Effort
~3–4 hours (depends on whether the read-back polling already exists).

---

## Effort Estimate

| Status | Proposal | Effort |
|---|---|---|
| ✅ Done | Phase 1 — auth + read-only fetch | ~2–3 hours |
| Open | Import ADO item → local TodoItem | ~2–3 hours |
| Open | Push completion state + sync queue | ~3–4 hours |
| Open | Push due dates + create ADO items | ~3 hours |
| Open | Push tracked time as `CompletedWork` field | ~2 hours |
| Open | Read-back + conflict surfacing | ~3–4 hours |
| Open | Link existing local task to ADO | ~1–2 hours |
| Open | Subtask completion → ADO comment (with prompt) | ~2 hours |
| Open | Quick custom comment to current task's ADO | ~1–2 hours |
| Open | At-a-glance ADO indicator in lists | ~1 hour |
| Open | Notify ADO on task start (state / comment) | ~2 hours |
| Open | Push completion-time summary as ADO comment | ~1–2 hours |
| Open | Notifications for new ADO comments | ~3–4 hours |

---

## Risks & Considerations

- **ADO field names vary by process template** (Agile vs Scrum vs CMMI). Confirm your org's work item type and field names before coding.
- **Subtask mapping**: ADO has child work items (parent-child links). Decide if TimeControl subtasks should become ADO child tasks or just fields on the parent.
- **Conflict resolution**: If someone edits the ADO item directly, TimeControl won't know. Keep sync one-directional (TimeControl → ADO) to start.
- **Rate limits**: ADO has soft throttling. Batch updates (`/$batch` endpoint) help if syncing many items at once.
