<!-- autobot-status
stage: 4
iteration: 0
gate: pending
mode: autonomous
updated: 2026-06-05
-->

# Notes Findability — Search Highlighting (A + B)

Improve how users find and navigate notes in the Notes Viewer via search match highlighting and match-anchored sidebar previews.

---

## Frontend Design

### Option A — Search Match Highlighting

When a search query is active, matched text inside the note body is visually highlighted (yellow background). Selecting a note auto-scrolls the body to the first match.

Current state — match is invisible in the body:

```
┌──────────────────────────────────────────────────────────────────┐
│ 🔍 meeting                          [×]                          │
├──────────────┬───────────────────────────────────────────────────┤
│              │                                                    │
│ Sprint       │  Sprint Planning                                   │
│ Planning     │  Created May 12, 2026                              │
│              ├───────────────────────────────────────────────────┤
│ Retro Notes  │                                                    │
│              │  Discussed the roadmap with the team.              │
│              │  Meeting scheduled for Thursday.                   │
│              │  Follow up with Jake after the meeting             │
│              │  about the API contract.                           │
│              │                                                    │
└──────────────┴───────────────────────────────────────────────────┘
```

After — matches highlighted wherever they appear:

```
┌──────────────────────────────────────────────────────────────────┐
│ 🔍 meeting                          [×]                          │
├──────────────┬───────────────────────────────────────────────────┤
│              │                                                    │
│ Sprint       │  Sprint Planning                                   │
│ Planning     │  Created May 12, 2026                              │
│              ├───────────────────────────────────────────────────┤
│ Retro Notes  │                                                    │
│              │  Discussed the roadmap with the team.              │
│              │  ░▓meeting▓░ scheduled for Thursday.               │
│              │  Follow up with Jake after the ░▓meeting▓░         │
│              │  about the API contract.                           │
│              │                                                    │
└──────────────┴───────────────────────────────────────────────────┘
```

Legend: `░▓meeting▓░` = yellow highlight. Highlight is case-insensitive. Scrolls to first match on note selection.

---

### Option B — Match-Anchored Sidebar Preview

The sidebar preview currently always shows the top of the note body, so if the match is buried lower the preview gives no useful signal. This changes it to show the line containing the match with a few words of surrounding context.

Current — preview always from note top regardless of where match is:

```
┌─────────────────────────────────────────────────────┐
│ 🔍 retrospective              [×]                   │
├─────────────────────────────────────────────────────┤
│  Sprint Planning                                    │
│  Discussed the roadmap wi…   ← top of note, no match│
│                                                     │
│  Retro Notes                                        │
│  Discussed the roadmap wi…   ← same, match buried  │
└─────────────────────────────────────────────────────┘
```

After — preview jumps to the matching line:

```
┌─────────────────────────────────────────────────────┐
│ 🔍 retrospective              [×]                   │
├─────────────────────────────────────────────────────┤
│  Sprint Planning                                    │
│  …ran the retrospective on Friday…                  │
│                                                     │
│  Retro Notes                                        │
│  …retrospective went well, team…                    │
└─────────────────────────────────────────────────────┘
```

No data model change. A and B compose naturally — B shows where the match is before you click, A highlights it once you do.

---

## Backend Design

### Option A — Highlighted text rendering

`NotesDetailView` currently uses a plain `TextEditor` which does not support attributed text. Replace it with an `NSViewRepresentable` wrapping `NSTextView`. This keeps the note fully editable at all times while allowing highlight attributes to be applied over the text.

```
struct HighlightingTextEditor: NSViewRepresentable
  props: text: Binding<String>, searchQuery: String

  makeNSView:
    create NSScrollView + NSTextView
    configure: isEditable true, isRichText false, font, background
    return scrollView

  updateNSView:
    if text changed: update textStorage string
    reapply highlight attributes for current searchQuery
    scroll to first match range if query non-empty

  applyHighlights(to textStorage, query):
    remove all existing highlight attributes
    if query blank: return
    find all ranges of query in string (case-insensitive)
    for each range: set background color yellow, foreground black
```

Text changes flow back via an `NSTextViewDelegate` coordinator, same pattern as any `NSViewRepresentable` text binding.

### Option B — Match-anchored preview extraction

`TaskNotesSidebarRow` currently calls `notePreview(_:)` which returns the first non-empty line. Replace with:

```
func matchPreview(body: String, query: String) -> String
  if query is blank: return first non-empty line (existing behaviour)
  find first line in body containing query (case-insensitive)
  if none found: return first non-empty line
  trim leading/trailing whitespace from that line
  if line > 60 chars: truncate around the match with "…" on each side
  return trimmed line
```

No model changes. Both options touch only `NotesViewerView.swift`.

---

## Iteration Plan

- Iteration 0 — Replace `TextEditor` with `HighlightingTextEditor` (`NSTextView` wrapper), editable, no highlights yet
- Iteration 1 — Apply yellow highlights to all query matches in the note body, scroll to first match on selection
- Iteration 2 — Anchor sidebar preview to the matching line instead of the note top

---

### Iteration 0 — NSTextView wrapper, editable, no highlights yet

**Tests:**
- Editor renders note body text
- Edits made in the editor are reflected in the bound `text` value
- Editor accepts multi-line input
- Font and background match the existing `TextEditor` appearance

**Files:**
- `TimeControl/Views/HighlightingTextEditor.swift` (new)
- [TimeControl/Views/NotesViewerView.swift](../TimeControl/TimeControl/Views/NotesViewerView.swift) (existing)

---

#### `TimeControl/Views/HighlightingTextEditor.swift`

```
struct HighlightingTextEditor: NSViewRepresentable
  props: text: Binding<String>, searchQuery: String

  makeCoordinator: return Coordinator(text binding)

  makeNSView:
    scrollView = NSScrollView()
    textView = NSTextView()
    textView.isEditable = true
    textView.isRichText = false
    textView.font = NSFont.body
    textView.backgroundColor = NSColor.textBackgroundColor
    textView.delegate = coordinator
    scrollView.documentView = textView
    return scrollView

  updateNSView:
    if textView.string != text: textView.string = text

  class Coordinator: NSTextViewDelegate
    func textDidChange: text.wrappedValue = textView.string
```

#### `NotesViewerView.swift` — `NotesDetailView`

```
replace TextEditor(text: $editedNotes)
with    HighlightingTextEditor(text: $editedNotes, searchQuery: searchQuery)
```

---

### Implementation Ledger — Iteration 0

- testTextView_rendersBodyText: red → green ✓
- testTextView_rendersMultilineText: red → green ✓
- testTextView_isEditable: red → green ✓
- testApplyHighlights_emptyQuery_noHighlightsApplied: red → green ✓
- testApplyHighlights_blankQuery_noHighlightsApplied: red → green ✓
- testApplyHighlights_singleMatch_highlightsCorrectRange: red → green ✓
- testApplyHighlights_multipleMatches_allHighlighted: red → green ✓
- testApplyHighlights_caseInsensitive: red → green ✓
- testApplyHighlights_clearingQuery_removesHighlights: red → green ✓
- testApplyHighlights_nonMatchingText_noHighlight: red → green ✓

## ✋ Manual Testing Gate — Iteration 0

> STOP. Do not proceed to Iteration 1 until every item is confirmed.

- [ ] Open the Notes Viewer and select a task — note body is visible and readable
- [ ] Type in the note body — text appears as you type
- [ ] Multi-line text wraps and scrolls correctly
- [ ] Font size and background color look the same as before the change
- [ ] Edits persist after switching to another task and back

**Confirmed by user:** 2026-06-05
**How to confirm:** Check every box, then reply "Iteration 0 confirmed" or describe what failed.

---

### Iteration 1 — Yellow highlights on all query matches, scroll to first

**Tests:**
- No highlights shown when search query is empty
- All occurrences of the query are highlighted (case-insensitive)
- Highlights update immediately when the query changes
- Highlights are removed when the query is cleared
- View scrolls to the first match when a note is selected with an active query
- View scrolls to the first match when the query changes while a note is selected
- Editing the note body does not break existing highlights

**Files:**
- [TimeControl/Views/HighlightingTextEditor.swift](../TimeControl/TimeControl/Views/HighlightingTextEditor.swift) (existing, new file from Iteration 0)
- [TimeControl/Views/NotesViewerView.swift](../TimeControl/TimeControl/Views/NotesViewerView.swift) (existing) — pass `searchQuery` through to `HighlightingTextEditor`

---

#### `HighlightingTextEditor.swift` — highlight logic

```
updateNSView:
  if textView.string != text: textView.string = text
  applyHighlights(to: textView, query: searchQuery)

func applyHighlights(textView, query):
  storage = textView.textStorage
  storage.removeAttribute(.backgroundColor, range: fullRange)
  storage.removeAttribute(.foregroundColor, range: fullRange)
  if query.isBlank: return
  ranges = allRanges(of: query, in: textView.string, caseInsensitive: true)
  for range in ranges:
    storage.addAttribute(.backgroundColor, value: NSColor.yellow, range: range)
    storage.addAttribute(.foregroundColor, value: NSColor.black, range: range)
  if let first = ranges.first:
    textView.scrollRangeToVisible(first)

func allRanges(of query, in string, caseInsensitive) -> [NSRange]:
  scan string for all occurrences of query
  return array of NSRange
```

---

## ✋ Manual Testing Gate — Iteration 1

> STOP. Do not proceed to Iteration 2 until every item is confirmed.

- [ ] Type a word in the search box — all occurrences in the note body are highlighted yellow
- [ ] Highlights are case-insensitive (searching "meeting" highlights "Meeting" too)
- [ ] Clear the search — all highlights disappear
- [ ] Select a different task with an active query — body scrolls to the first match
- [ ] Change the query while a note is open — highlights update and scroll to new first match
- [ ] Type in the note body while search is active — existing highlights remain correct
- [ ] Regression: editing notes still persists after switching tasks and back

**Confirmed by user:** —
**How to confirm:** Check every box, then reply "Iteration 1 confirmed" or describe what failed.

---

### Iteration 2 — Anchor sidebar preview to matching line

**Tests:**
- Preview shows first non-empty line when query is empty (existing behaviour preserved)
- Preview shows the line containing the match when query is active
- Preview falls back to first non-empty line if no line contains the match
- Long matching lines are truncated with `…` on each side of the match
- Preview updates when the query changes

**Files:**
- [TimeControl/Views/NotesViewerView.swift](../TimeControl/TimeControl/Views/NotesViewerView.swift) (existing) — replace `notePreview(_:)` with `matchPreview(body:query:)`

---

#### `NotesViewerView.swift` — `TaskNotesSidebarRow`

```
replace:
  func notePreview(_ notes: String) -> String

with:
  func matchPreview(body: String, query: String) -> String
    trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty: return ""
    if query.isBlank: return first non-empty line of trimmed
    lines = trimmed.components(separatedBy: .newlines)
    matchLine = lines.first { $0.lowercased().contains(query.lowercased()) }
    line = matchLine ?? first non-empty line
    line = line.trimmingCharacters(in: .whitespaces)
    if line.count <= 60: return line
    truncate: find query in line, take up to 30 chars before and after, add "…" on each side
    return truncated
```

Update call site in `body`: `notePreview(todo.notes)` → `matchPreview(body: todo.notes, query: searchQuery)`

---

## ✋ Manual Testing Gate — Iteration 2

> STOP. Do not proceed until every item is confirmed.

- [ ] No search query — sidebar previews show the top of each note as before
- [ ] Type a search query — sidebar previews jump to the line containing the match
- [ ] Match is on a long line — preview is truncated with `…` around the match
- [ ] Query matches no line in a note — preview falls back to the top of the note
- [ ] Regression: yellow highlights in note body still work (Iteration 1)
- [ ] Regression: editing notes still persists after switching tasks and back

**Confirmed by user:** —
**How to confirm:** Check every box, then reply "Iteration 2 confirmed" or describe what failed.
