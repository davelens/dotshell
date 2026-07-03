# No custom Command wrapper — Quickshell.Io types are the seam

An architecture review (2026-07) proposed a `Command` module to absorb the
hand-rolled process-output pattern (`property string output` + `onStarted`
reset + `SplitParser` accumulation, 32 copies at the time). Quickshell
already ships the deep modules, so a wrapper would be a pass-through:

- `StdioCollector` collects a whole stdout/stderr stream; buffer resets per
  run and `text` is complete inside `onExited` (verified empirically on
  Quickshell 0.3.0).
- `FileView.setText()` writes atomically by default — no `sh -c` heredoc
  staging needed for config saves.
- `Process.environment` passes env vars — no `VAR=x cmd` shell wrappers.

Conventions instead of a wrapper: one-shot output capture uses
`StdioCollector`; `SplitParser` is reserved for genuine line/event
streaming; user- or device-provided values never get concatenated into
`sh -c` strings — use argv elements, `environment`, or `"$@"` positional
args. Do not re-propose a Command abstraction unless these conventions
prove insufficient.
