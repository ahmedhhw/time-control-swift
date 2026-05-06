# Import from ADO — UI Design & TDD Plan

## Proposed Layout

The import sheet expands the current single-fetch field into three sections:
1. **Assigned to me** — stories assigned to the current user, not yet imported
2. **Mentioned in** — stories where the user was @mentioned
3. **Fetch by ID/URL** — the existing manual fetch field

---

```
┌─────────────────────────────────────────────────────────────┐
│  Cancel          Import from Azure DevOps          Import   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Assigned to me                          [Refresh ↻]       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ☐  #48210  Migrate auth flow to MSAL          Active  │  │
│  │ ☐  #47903  Add retry logic to sync service    Active  │  │
│  │ ☐  #46711  Resolve flaky unit tests            New    │  │
│  │ ☐  #46204  Update onboarding copy             Active  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Mentioned in                            [Refresh ↻]       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ☐  #48301  Design review: settings screen     Active  │  │
│  │ ☐  #47120  Crash in background fetch (iOS 17)  Bug   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ─────────────────── or fetch by ID ────────────────────   │
│                                                             │
│  Work Item ID or URL                                        │
│  ┌──────────────────────────────────────────┐  ┌───────┐   │
│  │ e.g. 12345 or paste full URL             │  │ Fetch │   │
│  └──────────────────────────────────────────┘  └───────┘   │
│                                                             │
│  ✓ Found work item                                          │
│    #48105                                                   │
│    Implement dark mode toggle                               │
│    ┌─────────────────────────────────────────────────────┐ │
│    │ Description (preview):                              │ │
│    │ Add a toggle in Settings > Appearance to switch     │ │
│    │ between light and dark mode. Should persist across  │ │
│    │ sessions via UserDefaults...                        │ │
│    └─────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Interaction Notes

- **Checkboxes** — user selects any combination of items from the two lists
- **Import button** — imports all checked items + the fetched-by-ID item (if any); disabled when nothing is selected and no item is fetched
- **Refresh buttons** — re-fetches each list independently; shows a spinner inline while loading
- Lists show a loading skeleton on first open, and an empty state ("No items") if none are returned
- Already-imported items (matched by ADO ID) are greyed out and pre-checked with a "Already added" label instead of a checkbox
- Each row is clickable to expand a preview (title + description snippet) inline before importing

---

## TDD Implementation Plan

### Conventions (from existing tests)

- Test files: `TimeControlTests/` target, `@testable import TimeControl`
- All VM tests are `@MainActor final class … : XCTestCase`
- Network faking: `MockURLProtocol` with a `requestHandler` closure reset in `tearDown`
- Isolated `UserDefaults`: `UserDefaults(suiteName: UUID().uuidString)!` per test
- Service injected via init; settings injected via `ADOSettingsStore(defaults:)`
- No mocking frameworks — plain `MockURLProtocol` + dependency injection

---

### Step 1 — Extend `ADOService` with two new fetch methods (Red → Green → Refactor)

**New API surface needed:**

```swift
// in ADOService
func fetchAssignedWorkItems(org: String, project: String, pat: String) async throws -> [ADOWorkItem]
func fetchMentionedWorkItems(org: String, project: String, pat: String) async throws -> [ADOWorkItem]
```

Both hit the ADO WIQL endpoint (`_apis/wit/wiql`) with a query:
- Assigned: `WHERE [System.AssignedTo] = @Me AND [System.State] <> 'Closed'`
- Mentioned: `WHERE [System.ChangedBy] <> @Me AND [System.State] <> 'Closed'` — items changed by others (indicating potential mentions/discussions)

**Test file:** `ADOBulkFetchTests.swift` (new)

**Red tests to write first:**

```
testFetchAssignedReturnsWorkItems          — 200 with valid WIQL JSON → [ADOWorkItem]
testFetchAssignedReturnsEmptyOnNoResults   — 200 with empty workItems array → []
testFetchAssignedThrowsUnauthorized        — 401 → ADOError.unauthorized
testFetchAssignedThrowsNetworkUnavailable  — URLError.notConnectedToInternet → ADOError.urlError(...)
testFetchMentionedReturnsWorkItems         — same shape as assigned tests
testFetchMentionedThrowsUnauthorized
```

**WIQL response shape (to mock):**

```json
{
  "workItems": [
    { "id": 48210, "url": "https://..." },
    { "id": 47903, "url": "https://..." }
  ]
}
```

The WIQL endpoint returns only IDs; a second batch call to
`_apis/wit/workitemsbatch` fetches titles/states in one round-trip.

**Batch request/response shape:**

```json
// POST body
{ "ids": [48210, 47903], "fields": ["System.Title", "System.State", "System.Description"] }

// Response
{
  "value": [
    { "id": 48210, "fields": { "System.Title": "Migrate auth...", "System.State": "Active", "System.Description": "" } }
  ]
}
```

`ADOWorkItem` needs a new optional field: `state: String?`

---

### Step 2 — Extend `ADOImportViewModel` (Red → Green → Refactor)

**New published state:**

```swift
@Published var assignedItems: [ADOWorkItem] = []
@Published var mentionedItems: [ADOWorkItem] = []
@Published var selectedIds: Set<Int> = []
@Published var isLoadingAssigned: Bool = false
@Published var isLoadingMentioned: Bool = false
@Published var assignedError: String?
@Published var mentionedError: String?
```

**New methods:**

```swift
func loadAssigned() async
func loadMentioned() async
func toggleSelection(_ id: Int)
var canImport: Bool  // selectedIds not empty OR fetchedItem != nil
func importSelected(existingAdoIds: Set<String>) -> [TodoItem]
```

**Test file:** Add new `@MainActor` test class or extend `ADOImportViewModelTests.swift`

**Red tests to write first:**

```
testLoadAssignedPopulatesAssignedItems
testLoadAssignedSetsIsLoadingThenClears
testLoadAssignedOnErrorSetsAssignedError
testLoadMentionedPopulatesMentionedItems
testLoadMentionedOnErrorSetsMentionedError

testToggleSelectionAddsId
testToggleSelectionRemovesAlreadySelectedId

testCanImportFalseWhenNothingSelectedAndNoFetch
testCanImportTrueWhenItemSelected
testCanImportTrueWhenFetchedItemPresent

testImportSelectedReturnsTodoItemsForSelectedIds
testImportSelectedIncludesFetchedItem
testImportSelectedExcludesAlreadyImportedIds   — item in existingAdoIds is skipped
testImportSelectedReturnsEmptyWhenNothingSelected
```

---

### Step 3 — Update `ADOImportView` (view only, no new tests)

Views are not unit-tested in this project. Wire the new VM state to UI:

- Add `assignedItems` list with checkboxes bound to `vm.selectedIds`
- Add `mentionedItems` list with checkboxes
- Refresh buttons call `vm.loadAssigned()` / `vm.loadMentioned()`
- Already-imported rows: pass `existingAdoIds: Set<String>` into the view from `ContentView`; greyed + labelled "Already added" when `existingAdoIds.contains(String(item.id))`
- Import button calls `vm.importSelected(existingAdoIds:)` and passes results to `onImport` closure (change signature from `(TodoItem) -> Void` to `([TodoItem]) -> Void`)
- `canImport` gates the Import button

**`ContentView` change:** derive `existingAdoIds` from `viewModel.todos.compactMap(\.adoWorkItemId)` and pass it into `ADOImportView`.

---

### Execution order

| # | What | File(s) | Cycle |
|---|------|---------|-------|
| 1 | Add `state` field to `ADOWorkItem` | `ADOService.swift` | prep (no test needed — additive) |
| 2 | Write `ADOBulkFetchTests` | `ADOBulkFetchTests.swift` (new) | Red |
| 3 | Implement `fetchAssignedWorkItems` + `fetchMentionedWorkItems` in `ADOService` | `ADOService.swift` | Green |
| 4 | Refactor shared WIQL + batch logic into a private helper | `ADOService.swift` | Refactor |
| 5 | Write new VM tests (assigned/mentioned/selection/import) | `ADOImportViewModelTests.swift` | Red |
| 6 | Extend `ADOImportViewModel` with new state + methods | `ADOImportViewModel.swift` | Green |
| 7 | Refactor VM if needed | `ADOImportViewModel.swift` | Refactor |
| 8 | Update `ADOImportView` + `ContentView` | `ADOImportView.swift`, `ContentView.swift` | UI wiring |
