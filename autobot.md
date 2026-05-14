# Autobot — Design-First TDD Feature Builder

Given a feature description, autobot guides you through four stages: design, high-level plan, full TDD plan with code, then hands off to the user for phased implementation.

## How to invoke

```
/autobot <feature description>
/autobot <ADO work item URL or ID>
```

When invoked, immediately announce: "I am using autobot." before doing anything else.

If no argument is given, ask the user for either a feature description or an ADO work item URL/ID before proceeding.

---

## Stage 1 — Design

**Goal:** Gather feature context (from description or ADO), then produce a `autobot-<feature-slug>.md` design document before writing a single line of code.

### Step 1a — Gather feature context

Determine whether the user provided a plain description or an ADO reference:

**If the argument looks like an ADO work item** (a numeric ID, a URL containing `dev.azure.com` or `visualstudio.com`, or the user says "ADO ticket #N"):

1. **Try the ADO MCP first** — check whether an ADO MCP server is available in the current session. If it is, use it to fetch the work item (title, description, acceptance criteria, comments).

2. **Fallback — REST API with PAT** — if no ADO MCP is available, ask the user for:
   - Their ADO organisation URL (e.g. `https://dev.azure.com/myorg`)
   - A Personal Access Token with `Work Items (Read)` scope

   Then fetch via the ADO REST API:
   - Work item details: `GET https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?$expand=all&api-version=7.1`
   - Comments: `GET https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}/comments?api-version=7.1-preview.3`
   - Auth: `Authorization: Basic <base64(":" + PAT)>`

3. Extract from whichever source was used:
   - **Title** (`fields["System.Title"]`)
   - **Description** (`fields["System.Description"]` — strip HTML tags)
   - **Acceptance Criteria** (`fields["Microsoft.VSTS.Common.AcceptanceCriteria"]` — strip HTML tags)
   - **Comments** (each comment's `text` field — strip HTML tags)

4. Present the extracted content to the user and confirm it looks correct before continuing

**If the argument is a plain description:** use it directly as the feature context.

### Step 1b — Design document

Steps:
1. Clarify scope with the user if the feature context is ambiguous
2. Determine where to create `autobot-<feature-slug>.md`: check if a `docs/` folder exists at the repo root — if it does, place the file there; otherwise place it at the repo root
3. Write the document with these sections:

```
# <Feature Name>

## Overview
One paragraph describing what this feature does and why.

## UI / Flow
ASCII mockup(s) of every screen or state the user will see.
Label each mockup (e.g. "Empty state", "Loaded state", "Error state").

## Architecture
Mermaid diagram(s) showing:
- Data flow (sequence diagram if async, component diagram if structural)
- New models, services, or view models and how they relate

## Open Questions
Bullet list of any ambiguities or decisions still to make.
```

4. Show the document to the user and **stop**.

   - If the **Open Questions** section is non-empty, ask each question explicitly and **refuse to proceed to Stage 2** until every question has been answered by the user. Once answered, update the design doc to reflect the decisions and remove the resolved questions from the list.
   - Only when Open Questions is empty, ask:
     > "Does this design look right? Any changes before I move to Stage 2?"

Do not proceed to Stage 2 until the user explicitly approves AND there are no remaining open questions.

---

## Stage 2 — High-Level Implementation Steps

**Goal:** Produce a concise, numbered list of the high-level steps needed to build this feature — no code, no test details yet.

Steps:
1. Read the approved design document
2. Identify the major work items (models, services, views, wiring, etc.)
3. Append a new section to `autobot-<feature-slug>.md`:

```
## High-Level Steps

1. <Step one — e.g. "Add X field to TodoItem model">
2. <Step two — e.g. "Update ViewModel with Y method">
3. <Step three — ...>
...
```

Keep each step to one line. Aim for 5–12 steps total. No code, no sub-bullets — just the ordered sequence of work. Do not mention "test" or "tests" in any step — TDD is always assumed and will be covered in Stage 3.

4. Show the updated document to the user and **stop**. Ask:
   > "Do these steps look right? Any changes before I write the full TDD plan in Stage 3?"

Do not proceed to Stage 3 until the user explicitly approves or asks for changes.

---

## Stage 3 — Full TDD Plan with Code

**Goal:** Expand the high-level steps into a complete, phased TDD plan with full code written directly in the markdown file.

Steps:
1. Read the approved high-level steps
2. Detect the project's primary language by reading existing source files — use that language's conventions, idioms, and test framework in all generated code
3. Group the steps into the **smallest meaningful implementation phases** — each phase independently testable
4. For each phase, append a section to `autobot-<feature-slug>.md` with:
   - The failing tests **written in full** (complete test code, not pseudocode)
   - The production code **written in full** (complete implementation code, not pseudocode)
   - Acceptance criteria

Use this format for each phase:

```
## Implementation Phases

### Phase N — <Short Phase Name>
**What it covers:** One sentence.

**Tests (Red) — write these first:**
\`\`\`
// Full test code here — complete, copy-pasteable
\`\`\`

**Production code (Green):**
\`\`\`
// Full implementation code here — complete, copy-pasteable
\`\`\`

**Done when:** Observable acceptance criteria (not just "tests pass").
```

5. After all phases, append a top-level feature acceptance checklist:

```
## Feature Acceptance Checklist

- [ ] <observable end-to-end behaviour 1>
- [ ] <observable end-to-end behaviour 2>
- [ ] <edge case or error state covered>
- [ ] All phases green (tests pass, no regressions)
```

This checklist reflects the feature's acceptance criteria from the design doc — not individual phase completion. It is the user's definition of done for the entire feature.

6. **Ask the user how they want to test the feature manually:**

   > "Before I hand off — how do you want to test this in the UI?
   > - **A) Real credentials only** — checklist of what to configure and what to look for
   > - **B) Mock server** — a local Python server that intercepts the app's API calls so you can test without real credentials
   > - **C) Both**"

   Wait for the user's answer, then append a `## How to Test` section to the doc based on their choice:

   **If real credentials (A or C):** Write a table of required credentials/config, numbered setup steps in the app's Settings or UI, and a checkbox list of what to verify — including the happy path, error states (bad credentials, network off, empty results), and any regressions to check.

   **If mock server (B or C):** Write a complete, runnable Python 3 script (`mock_server.py` at the repo root) that:
   - Uses only the standard library (`http.server`, `json`, `urllib.parse`)
   - Intercepts every API endpoint the feature calls (match on path + method)
   - Returns realistic JSON payloads for the happy path by default
   - Includes commented-out alternative handlers to simulate error states (401, 500, empty results, slow response via `time.sleep`)
   - Prints each incoming request to stdout so the user can see what the app is calling
   - Runs on `localhost:8080` (or the port that makes sense for the project) with a one-liner: `python3 mock_server.py`
   - Includes clear instructions for how to point the app at `localhost` instead of the real API (e.g. override the base URL in a debug build flag or Settings)

   All code in the How to Test section must be complete and runnable — no pseudocode.

7. Show the full updated document to the user and **stop**. Do not implement anything.

---

## Stage 4 — Hand Off

**Goal:** Give the user clear instructions for driving the implementation themselves, then exit.

Tell the user:

> "The plan is ready. Review each phase in `autobot-<feature-slug>.md`, then implement it one phase at a time using normal prompts. For example:
>
> - 'Implement Phase 1'
> - 'Implement Phase 2'
> - 'Implement Phase 3'
>
> Each phase has the full test and production code already written — paste or describe what you need and I'll help you wire it in."

Then **stop**. Do not begin any implementation. The user will drive each phase manually.

---

## Rules

- Never write production code before a failing test for it exists
- Never advance to the next stage without user sign-off (except Stage 4, which terminates)
- **Do NOT move to Stage 2 if there are any open questions or ambiguities — resolve every one of them with the user first**
- All code in the plan must be complete and copy-pasteable — no pseudocode, no `// ...` ellipsis
- Keep phases small — one cohesive behaviour at a time
- If a phase turns out larger than expected, split it and re-present the updated plan
