# ai-agents-monitor — Rust rewrite plan

Ports `modules/ai-agents-monitor/` (Manager + Segment, ~698 lines QML).
Segment aggregating OpenCode, Claude Code, and pi session states into
busy/idle/error/question counts.

## Feature parity

- Three providers, merged only when all three finish a poll cycle
  (ports `_tryMerge`/`_mergeProviders` and the per-provider `_busy`
  flags):
  - **OpenCode**: discover instances via `bin/oc` /
    `claude-discover`-style discovery script, then query each local
    HTTP API (status, session, question, permission endpoints) with
    short connect/read timeouts (1s/2s today).
  - **Claude Code**: sessions/tasks directory scanning
    (`_ccSessionsDir`, `_ccTasksDir`).
  - **pi**: sessions directory scanning (`_piSessionsDir`).
- Counts exposed: `totalCount`, `busyCount`, `idleCount`,
  `errorCount`, `questionCount`; segment presentation (glyph 󰚩 +
  per-state counts/colors) unchanged.
- `bin/oc`, `bin/claude-discover`, `bin/pi-discover` stay bash and
  keep being symlinked into `$XDG_BIN_HOME` (or `~/.local/bin` when unset).

## Stack

- Module crate, segment component only (order 205).
- Poll timer on `calloop`; discovery via `collect_output` on the
  existing bin scripts (they are the contract — do not reimplement
  their logic in Rust).
- Local HTTP calls: `reqwest` on the tokio sidecar with the same 1s
  connect / 2s total timeouts (replaces the `curl -sf` chains); the
  sequential pending-queue walk (`_ocQueryNext` etc.) becomes a plain
  async loop per provider.
- Directory scans: `std::fs` + mtime checks, same semantics.

## State / IPC / keymaps

- No persisted state, no IPC verbs, no popup, no own keymaps (passive
  segment in bar focus mode).

## Risks

- The provider state machines are the densest QML in the repo; port
  each provider behind its own `Provider` trait impl with unit tests
  against captured API fixtures before wiring the segment.

## Verification

- With one busy OpenCode session, one idle Claude session: counts
  match the current shell side-by-side; unreachable API (killed
  instance) degrades to removal within one cycle, no hang (timeouts).
