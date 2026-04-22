# Fix `resizeWindow()` Race Conditions — Option 3: Reactive `onChange` (TDD Plan)

## Context

`resizeWindow()` in [FloatingTaskWindowView.swift](../TimeControl/Views/FloatingTaskWindowView.swift) is called from 11 places and always dispatches via `DispatchQueue.main.async`. This causes 5 race conditions: queue pile-up from rapid state changes, stale state reads at dequeue time, double-resize from layout-not-committed, timer-completion cascade (3–4 stacked dispatches), and inconsistent mid-calculation state reads in `calculateDynamicHeight()`.

Option 3 eliminates all five at the root: remove all explicit `resizeWindow()` call sites and replace with a single reactive `.onChange(of: currentSnapshot, initial: true)` that fires after SwiftUI's committed render pass.

### What Option 3 actually buys you

`applyResize` will still wrap its body in `DispatchQueue.main.async` (inherited from the old `resizeWindow`). The race-condition fix comes from two properties of `.onChange`, **not** from removing the dispatch:

1. **Equatable dedup** — identical snapshots don't re-fire
2. **Committed-layout guarantee** — the closure runs after SwiftUI has committed the layout pass, so reads see final state

If anyone later reintroduces `applyResize` calls from non-`onChange` sites, pile-up returns. State this in a code comment next to `applyResize`.

---

## Critical File

- [TimeControl/Views/FloatingTaskWindowView.swift](../TimeControl/Views/FloatingTaskWindowView.swift)

---

## What's Testable vs. Not

The project uses plain XCTest with no view testing infrastructure (no ViewInspector, no snapshot tests). The view-layer NSWindow resize cannot be unit tested directly. What **can** be unit-tested:

- `calculateDynamicHeight(snapshot:)` — pure function after extraction
- `ResizeSnapshot` equality — ensures dedup works

What **must** be manually verified:

- Reactive wiring (`.onChange` firing, debouncing, animation coupling) — no unit test surface

The TDD cycles below apply **only** to the pure-function extraction and the `Equatable` contract. Phases 3–4 are structural refactors guarded by the passing tests from Phases 1–2 plus the Swift compiler.

---

## Phase 0 — Preparation (no code changes)

1. Confirm `localTask.countdownTime` is the **configured duration**, not the live-ticking remaining time. If it ticks every second, it must NOT go into `ResizeSnapshot` — it would flood `.onChange`. Based on the model (`countdownTime`, `countdownElapsedAtPause`, `countdownStartTime`), it is the configured total. **Verify by grep** before Phase 1.
2. Read existing tests under `TimeControlTests/` to learn the project's assertion style and factory helpers.

---

## Phase 1 — TDD: extract pure `calculateDynamicHeight(snapshot:)`

Each cycle below is **one behaviour**, red → green → refactor. Do not batch cycles. Run the test suite between steps.

### Cycle 1.0 — Scaffolding (red)

**Red.** Create `TimeControlTests/ResizeSnapshotTests.swift` with a single test:

```swift
func test_collapsed_returnsFiftyPoints() {
    let snap = ResizeSnapshot.fixture(isCollapsed: true)
    XCTAssertEqual(calculateDynamicHeight(snapshot: snap), 50)
}
```

This fails to compile: `ResizeSnapshot` and `calculateDynamicHeight(snapshot:)` don't exist.

**Green.** In [FloatingTaskWindowView.swift](../TimeControl/Views/FloatingTaskWindowView.swift), add (file-scope, `internal` for test access, or wrap tests with `@testable import`):

```swift
struct ResizeSnapshot: Equatable {
    var isCollapsed: Bool = false
    var subtaskContentHeight: CGFloat = 0
    var descriptionText: String = ""
    var windowWidth: CGFloat = 350
    var countdownTime: TimeInterval = 0
    var showTimerBar: Bool = false
    var showTimerCompletedMessage: Bool = false
    var estimatedTime: TimeInterval = 0
    var dueDate: Date? = nil
    var showEstimateBar: Bool = false
    var showDueDateBar: Bool = false

    static func fixture(...) -> ResizeSnapshot { ... }  // all-default helper
}

func calculateDynamicHeight(snapshot s: ResizeSnapshot) -> CGFloat {
    if s.isCollapsed { return 50 }
    return 380  // minimum from the clamp; just enough to fail later cycles
}
```

Test passes. **Do not** port the full existing logic yet — each subsequent cycle drives one more branch.

**Refactor.** None yet.

### Cycle 1.1 — Minimum clamp (380)

**Red.** Add:

```swift
func test_empty_snapshot_clampsToMinimum380() {
    XCTAssertEqual(calculateDynamicHeight(snapshot: .fixture()), 380)
}
```

Passes already (green skeleton returns 380). Good — confirms the floor.

**Red for real.** Add:

```swift
func test_fullSections_belowMinimum_stillReturns380() {
    let snap = ResizeSnapshot.fixture(subtaskContentHeight: 0)
    // base header + title + time section + buttons + empty-subtask 80 ≈ 300 < 380
    XCTAssertEqual(calculateDynamicHeight(snapshot: snap), 380)
}
```

Will pass with the stub. Move on.

### Cycle 1.2 — Maximum clamp (900)

**Red.**

```swift
func test_giantSubtaskHeight_clampsTo900() {
    let snap = ResizeSnapshot.fixture(subtaskContentHeight: 5000)
    XCTAssertEqual(calculateDynamicHeight(snapshot: snap), 900)
}
```

Fails: stub returns 380.

**Green.** Port the real addends enough to reach 900 under this input and apply the `min(max(h, 380), 900)` clamp. Stop as soon as the test passes.

### Cycle 1.3 — Subtask content height addend (capped at 400)

**Red.**

```swift
func test_subtaskHeight_cappedAt400_inAddend() {
    let big = ResizeSnapshot.fixture(subtaskContentHeight: 1000)
    let cap = ResizeSnapshot.fixture(subtaskContentHeight: 400)
    XCTAssertEqual(calculateDynamicHeight(snapshot: big),
                   calculateDynamicHeight(snapshot: cap))
}
```

### Cycle 1.4 — Subtask fallback when `subtaskContentHeight == 0`

**Red.**

```swift
func test_zeroSubtaskHeight_usesEightyPointFallback() {
    let zero = ResizeSnapshot.fixture(subtaskContentHeight: 0)
    let eighty = ResizeSnapshot.fixture(subtaskContentHeight: 80)
    XCTAssertEqual(calculateDynamicHeight(snapshot: zero),
                   calculateDynamicHeight(snapshot: eighty))
}
```

Drives the `subtaskContentHeight > 0 ? min(..., 400) : 80` branch at [line 1564](../TimeControl/Views/FloatingTaskWindowView.swift#L1564).

### Cycle 1.5 — Countdown timer sections

**Red.**

```swift
func test_countdownZero_addsNothing() {
    let off = ResizeSnapshot.fixture(countdownTime: 0, showTimerBar: true)
    let base = ResizeSnapshot.fixture()
    XCTAssertEqual(calculateDynamicHeight(snapshot: off),
                   calculateDynamicHeight(snapshot: base))
}

func test_countdownActive_barCollapsed_addsThirty() {
    let collapsed = ResizeSnapshot.fixture(countdownTime: 60, showTimerBar: false)
    let base = ResizeSnapshot.fixture()
    XCTAssertEqual(calculateDynamicHeight(snapshot: collapsed) -
                   calculateDynamicHeight(snapshot: base), 30)
}

func test_countdownActive_barExpanded_addsNinety() {
    let expanded = ResizeSnapshot.fixture(countdownTime: 60, showTimerBar: true)
    let base = ResizeSnapshot.fixture()
    XCTAssertEqual(calculateDynamicHeight(snapshot: expanded) -
                   calculateDynamicHeight(snapshot: base), 90)
}
```

### Cycle 1.6 — Timer completed message addend (120)

**Red.**

```swift
func test_timerCompletedMessage_adds120() {
    let on = ResizeSnapshot.fixture(showTimerCompletedMessage: true)
    let off = ResizeSnapshot.fixture(showTimerCompletedMessage: false)
    XCTAssertEqual(calculateDynamicHeight(snapshot: on) -
                   calculateDynamicHeight(snapshot: off), 120)
}
```

### Cycle 1.7 — Estimate bar (collapsed 30, expanded 100)

**Red.** Two tests mirroring the countdown cycle: `estimatedTime: 0` adds nothing; `estimatedTime > 0` with `showEstimateBar: false` adds 30; with `true` adds 100.

### Cycle 1.8 — Due date bar (collapsed 30, expanded 100)

**Red.** Mirror of Cycle 1.7 using `dueDate` / `showDueDateBar`.

### Cycle 1.9 — Description height scales with lines, capped at 148

**Red.**

```swift
func test_emptyDescription_adds28() {
    let empty = ResizeSnapshot.fixture(descriptionText: "")
    let oneLine = ResizeSnapshot.fixture(descriptionText: "x")
    XCTAssertLessThan(calculateDynamicHeight(snapshot: empty),
                      calculateDynamicHeight(snapshot: oneLine))
}

func test_veryLongDescription_cappedAt148() {
    let huge = ResizeSnapshot.fixture(
        descriptionText: String(repeating: "a", count: 10_000),
        windowWidth: 350
    )
    // cap is 148 addend; assert total matches a known truncated snapshot
    XCTAssertEqual(
        calculateDynamicHeight(snapshot: huge),
        calculateDynamicHeight(snapshot: ResizeSnapshot.fixture(
            descriptionText: String(repeating: "a", count: 10_000),
            windowWidth: 100 // even narrower — still capped
        ))
    )
}
```

Drives the `min(lines * 40 + 20, 148)` cap at [line 1529](../TimeControl/Views/FloatingTaskWindowView.swift#L1529).

### Cycle 1.10 — Refactor

With all Phase 1 cycles green:

- Remove the stub `return 380` placeholder if still present
- Make the original instance method a one-liner: `private func calculateDynamicHeight() -> CGFloat { calculateDynamicHeight(snapshot: currentSnapshot) }`
- Introduce `currentSnapshot` computed property on the view that assembles the struct from current state
- Re-run the full test suite

---

## Phase 2 — TDD: `ResizeSnapshot` Equality (dedup contract)

`Equatable` is synthesized automatically, so these tests document the contract rather than drive new code.

### Cycle 2.1

**Red.**

```swift
func test_identicalSnapshots_areEqual() {
    XCTAssertEqual(ResizeSnapshot.fixture(), ResizeSnapshot.fixture())
}

func test_differingSubtaskHeight_areNotEqual() {
    XCTAssertNotEqual(
        ResizeSnapshot.fixture(subtaskContentHeight: 100),
        ResizeSnapshot.fixture(subtaskContentHeight: 101)
    )
}

func test_differingCollapsed_areNotEqual() {
    XCTAssertNotEqual(
        ResizeSnapshot.fixture(isCollapsed: true),
        ResizeSnapshot.fixture(isCollapsed: false)
    )
}
```

All three should pass immediately given synthesized `Equatable`. If any fails, the struct definition is missing a stored field or has a non-`Equatable` member.

---

## Phase 3 — Reactive wiring (structural, not unit-testable)

No tests drive this phase; rely on Phase 1 tests staying green plus the compiler.

### 3.1 — Add `currentSnapshot` computed property

Already introduced in Cycle 1.10. Confirm it reads from the same state the old `calculateDynamicHeight()` did.

### 3.2 — Add `applyResize(_:)`

```swift
/// NOTE: must only be invoked from `.onChange(of: currentSnapshot, initial: true)`.
/// Direct calls reintroduce the `DispatchQueue.main.async` pile-up this refactor fixes.
private func applyResize(_ snapshot: ResizeSnapshot) {
    DispatchQueue.main.async {
        guard let window = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }),
              let screen = window.screen else { return }
        let currentFrame = window.frame
        let visible = screen.visibleFrame
        let rawHeight = calculateDynamicHeight(snapshot: snapshot)
        let newHeight = min(rawHeight, visible.height)
        var newY = currentFrame.maxY - newHeight
        if newY + newHeight > visible.maxY { newY = visible.maxY - newHeight }
        if newY < visible.minY { newY = visible.minY }
        let adjustedFrame = NSRect(x: currentFrame.minX, y: newY,
                                   width: currentFrame.width, height: newHeight)
        window.setFrame(adjustedFrame, display: true, animate: true)
    }
}
```

### 3.3 — Single `.onChange` in `body`

Pass `currentSnapshot` directly — no `resizeKey` alias:

```swift
.onChange(of: currentSnapshot, initial: true) { _, snapshot in
    applyResize(snapshot)
}
```

`initial: true` (macOS 14+) replaces the old `onAppear { DispatchQueue.main.async { resizeWindow() } }` — one fewer modifier, one fewer async hop.

### 3.4 — Break the `windowWidth` feedback loop

[windowWidth](../TimeControl/Views/FloatingTaskWindowView.swift#L46) is updated via `GeometryReader` + `WidthPreferenceKey` at [line 233](../TimeControl/Views/FloatingTaskWindowView.swift#L233). During a `setFrame(..., animate: true)` height animation, SwiftUI may re-measure and emit intermediate width values, retriggering `.onChange` every frame.

**Do one of:**

- Round `windowWidth` to the nearest 10pt inside `currentSnapshot` — absorbs measurement jitter without extra modifiers (preferred)
- Omit `windowWidth` from `ResizeSnapshot` entirely and call `applyResize(currentSnapshot)` directly from the preference-change handler only when `|Δ| > 4pt`

---

## Phase 4 — Remove all 11 `resizeWindow()` call sites (compiler-enforced refactor)

Delete one call site at a time. Run `xcodebuild` between each to confirm nothing else depended on the side effect.

1. `onAppear` at [line 238–240](../TimeControl/Views/FloatingTaskWindowView.swift#L238) — delete. `initial: true` on `.onChange` covers initial sizing
2. Collapse button `withAnimation` at [line 251](../TimeControl/Views/FloatingTaskWindowView.swift#L251) — remove `resizeWindow()`; `.onChange` fires after render
3. `onPreferenceChange(SubtaskContentHeightKey.self)` at [line ~578](../TimeControl/Views/FloatingTaskWindowView.swift#L578) — keep the mutation, delete the call
4. `onChange(of: showTimerCompletedMessage)` — delete entire modifier
5. `onChange(of: localTask.countdownTime)` — delete entire modifier
6. Timer auto-pause path at [~line 1084](../TimeControl/Views/FloatingTaskWindowView.swift#L1084) — delete the call
7. Timer completion path at [~line 1122](../TimeControl/Views/FloatingTaskWindowView.swift#L1122) — delete the call
8. `handleReminderResponse` at [~line 1185](../TimeControl/Views/FloatingTaskWindowView.swift#L1185) and [~line 1207/1212](../TimeControl/Views/FloatingTaskWindowView.swift#L1207) — delete both calls
9. `addSubtask()` at [~line 1689](../TimeControl/Views/FloatingTaskWindowView.swift#L1689) — delete
10. `deleteSubtask()` at [~line 1779](../TimeControl/Views/FloatingTaskWindowView.swift#L1779) — delete
11. `updateDescriptionLines()` at [line 1580–1586](../TimeControl/Views/FloatingTaskWindowView.swift#L1580) — **delete the whole function**, along with `@State descriptionVisualLines` and its call site from the `WidthPreferenceKey` handler at [line 234](../TimeControl/Views/FloatingTaskWindowView.swift#L234). `calculateDynamicHeight` reads `descriptionText` and `windowWidth` directly via the snapshot, so the cached line count is dead state

After this, `resizeWindow()` has no callers. **Delete it.** The Swift compiler guarantees no call site was missed.

Run the full `TimeControlTests` suite. Phase 1 + 2 tests must stay green; no other tests should regress.

---

## Phase 5 — Manual verification (no unit-test surface)

### 5.1 Animation coupling

The collapse button previously called `resizeWindow()` **inside** `withAnimation`. With `.onChange`, the resize fires one render cycle after the toggle. The NSWindow animation is driven by `setFrame(..., animate: true)` — a **separate** animation system from SwiftUI's `withAnimation`. Wrapping `applyResize` in `withAnimation` does **not** sync the two.

**If visible desync occurs:**

- Wrap `setFrame` in `NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.2; ... }` to match the SwiftUI 0.2s `.easeInOut`, OR
- Pass `animate: false` to `setFrame` and let SwiftUI drive height via a `.frame(height:)` modifier on the root view (larger refactor)

### 5.2 Behavioural checks in the running app

1. **Rapid subtask adding** — add 5 subtasks quickly; window grows smoothly without bouncing
2. **Collapse while adding** — add a subtask then immediately collapse; settles at 50pt
3. **Countdown timer completion** — 1-minute timer expires; window expands and shows "Timer's up!" in one smooth resize (not 3)
4. **Auto-pause** — trigger idle auto-pause; window expands once cleanly
5. **Task switch** — switch tasks rapidly in the picker; height reflects new task without flicker
6. **Resize window + type description** — drag window wider while typing; height recalculates without runaway loop (validates Phase 3.4)

---

## Files Changed

| File | Change |
|------|--------|
| [TimeControl/Views/FloatingTaskWindowView.swift](../TimeControl/Views/FloatingTaskWindowView.swift) | Add `ResizeSnapshot`, `currentSnapshot`, `applyResize(_:)`, pure `calculateDynamicHeight(snapshot:)`, single `.onChange(of:initial:)`; remove 11 call sites, `resizeWindow()`, `updateDescriptionLines()`, and `descriptionVisualLines` |
| `TimeControlTests/ResizeSnapshotTests.swift` | New — drives pure-function extraction via TDD cycles 1.0–1.10 and documents `Equatable` contract in 2.1 |

---

## TDD Discipline Checklist

- [ ] No production code is written before a failing test for it exists (Phases 1–2 only)
- [ ] Each cycle targets exactly one behaviour
- [ ] Every red test is confirmed to fail for the **right reason** (missing logic), not a compile error from an unrelated typo
- [ ] Green steps contain only the minimum code to pass — no extra fields, no extra branches
- [ ] Refactor runs after every green, with tests re-run after every change
- [ ] Phases 3–4 explicitly opt out of TDD and rely on the compiler + Phase 1–2 tests
