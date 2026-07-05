# clock — Rust rewrite plan

Ports `modules/clock/` (Segment only, ~37 lines QML) plus its
dependency on `core/Time.qml`.

## Feature parity

- Date + time text exactly as formatted today (same format string
  semantics as the current `Qt.formatDateTime` usage — transcribe the
  literal format from `Segment.qml` at port time).
- Updates on the minute boundary (no busy 1s tick unless the current
  format shows seconds — match whatever `Time.qml`'s interval is).

## Stack

- Module crate, segment component only (order 120).
- `jiff` for local time + formatting (tz-correct, actively
  maintained); `Time` becomes a tiny core service in `ds-core` that
  ticks a calloop timer aligned to the next boundary and broadcasts to
  subscribers (clock segment, notifications DND schedule check).

## State / IPC / keymaps

- None. Passive segment.

## Verification

- Rendered string byte-identical to the quickshell bar side-by-side
  across a midnight and a DST boundary (fake via `TZ`/`faketime`).
