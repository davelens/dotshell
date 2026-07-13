# active-collab — Rust rewrite plan

Ports `modules/active-collab/` (Manager + Segment, ~166 lines QML).
Passive bar segment showing running ActiveCollab time-tracking
sessions.

## Feature parity

- Poll `bin/list-sessions` (bash, stays as-is, symlinked into
  `$XDG_BIN_HOME` by the registry, with a `~/.local/bin` fallback) every 30s,
  triggered immediately on start.
- Parse JSON array `[{ project, sessionDescription, duration, start }]`;
  non-zero exit or empty output resets to zero tasks.
- Segment renders total count + running task info exactly as today;
  hidden/empty presentation rules unchanged.

## Stack

- Module crate `modules/active-collab/`, `Module` trait, segment
  component only (manifest unchanged: id, icon ``, order 206).
- `calloop` timer (30s, fire-on-start) → `collect_output(["bash",
  "<module dir>/bin/list-sessions"])` → `serde_json` parse into a
  typed `RunningTask` struct.

## State / IPC / keymaps

- No persisted state, no IPC verbs, no popup.
- Keymaps: none of its own; participates in bar focus mode as a
  passive segment (no `activate()` — focus-mode Enter dismisses, as
  today).

## Verification

- Segment appears with a running AC session, clears within 30s of
  stopping it; kill the script mid-poll → segment resets, no crash.
