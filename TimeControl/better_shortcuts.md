# Better Default Keyboard Shortcuts

## Goals
- Make related actions use the same modifier class and nearby letters.
- Keep task commands under Cmd, window state commands under Cmd+Shift, and quick focus/open actions under Option.
- Use mnemonic letters where possible so muscle memory maps to action names.
- Reduce distance between similar actions such as collapse, open comment, and focus comment.

## Recommended default scheme

### Command-level task actions (Cmd)
- `⌘ I` — Toggle timer (play/pause)
- `⌘ L` — Quick task switcher
- `⌘ O` — Complete task
- `⌘ D` — Open notes

### Command-level window actions (Cmd+Shift)
- `⌘ ⇧ Y` — Set countdown timer
- `⌘ ⇧ D` — Open notes viewer
- `⌘ ⇧ C` — Toggle collapse / expand floating task window

### Quick focus/open actions (Option)
- `⌥ C` — Open ADO comment and focus the comment field
- `⌥ S` — Open subtask input and focus the subtask field
- `⌥ H` — Open history view
- `⌥ M` — Show main window

### In-comment shortcuts
- `⌘ Return` — Send ADO comment when the comment field is focused
- `Return` — Insert a newline in the comment field

## Why this scheme works
- `C` is used for both comment and collapse, but with different modifiers:
  - `⌘ ⇧ C` for collapse
  - `⌥ C` for comment focus
- `S` is natural for subtasks, keeping `⌥ S` close to `⌥ C` on the keyboard.
- `H` remains history, a strong mnemonic.
- `M` is more intuitive than `B` for main window.
- Cmd-only actions remain core task operations, while Option-only actions become quick window-focused shortcuts.

## Optional refinement
If you want even tighter grouping, consider these optional pairs:
- `⌥ C` — ADO comment
- `⌥ S` — Subtask input
- `⌥ H` — History
- `⌥ M` — Main window

and keep `⌘ ⇧ C` for collapse, because it keeps all global window-state actions on Cmd+Shift.

## Suggested default binding table

| Action | Proposed default |
|---|---|
| Toggle timer | `⌘ ⇧ I` |
| Quick task switcher | `⌘ L` |
| Set countdown timer | `⌘ ⇧ Y` |
| Open notes | `⌘ D` |
| Open notes viewer | `⌘ ⇧ D` |
| Complete task | `⌘ O` |
| Collapse / expand floating window | `⌘ ⇧ C` |
| Open ADO comment + focus | `⌥ C` |
| Open subtask input + focus | `⌥ S` |
| Open history | `⌥ H` |
| Show main window | `⌥ M` |

## Notes
- `⌥ C` and `⌥ S` make the two quick content-entry actions adjacent on the keyboard and easy to reach.
- If `⌥ M` conflicts with another binding, `⌥ O` is a reasonable fallback for "open main window."
- `⌘ ⇧ C` is a much better mnemonic for collapse than `⌘ ⇧ E` because it directly matches the action name.

## Implementation suggestion
1. Keep the existing `Cmd` bindings for core task actions.
2. Move collapse into `Cmd+Shift+<letter>` with a mnemonic letter like `C`.
3. Move quick focus/open actions into `Option+<letter>` and choose letters from the action name.
4. Add a `Keyboard Shortcuts` settings section so users can remap these defaults if needed.

