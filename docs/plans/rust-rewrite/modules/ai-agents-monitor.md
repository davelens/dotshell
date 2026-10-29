# ai-agents-monitor — Rust rewrite plan

Ports `modules/ai-agents-monitor/` (Manager + Segment, ~698 lines QML).
Segment aggregating OpenCode, Claude Code, and pi session states into
busy/idle/error/question counts.

## Feature parity

- Agents push status over `$XDG_RUNTIME_DIR/dotshell-agents.sock` (one
  JSON line per change; see README "AI agent monitoring"). Persistent
  connections (Pi, OpenCode) own their agent until they close; one-shot
  Claude hook lines are pruned by a 60 s `bin/claude-discover` rescan,
  which also seeds pre-existing Claude sessions and heartbeats the
  remote snapshot.
- Counts exposed: `totalCount`, `busyCount`, `idleCount`,
  `errorCount`, `questionCount`; segment presentation (glyph 󰚩 +
  per-state counts/colors) unchanged.
- `bin/claude-discover` and `bin/claude-hook` stay bash.

## Stack

- Module crate, segment component only.
- Unix socket listener on `calloop`; line-delimited JSON, same
  validation as `Manager._apply`.
- 60 s rescan via `collect_output` on `bin/claude-discover`.

## State / IPC / keymaps

- No persisted state, no IPC verbs, no popup, no own keymaps (passive
  segment in bar focus mode).

## Risks

- Keep the ownership rule: a replaced Pi session reconnects before its
  old connection closes, so only drop agents the closing connection
  still owns.

## Verification

- With one busy OpenCode session, one idle Claude session: counts
  match the current shell side-by-side; a killed Pi/OpenCode instance
  disappears immediately, a killed Claude within a minute.
