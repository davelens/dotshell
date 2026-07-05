# system-load — Rust rewrite plan

Ports `modules/system-load/` (Manager + Segment, ~161 lines QML).
CPU and memory readout in the bar.

## Feature parity

- CPU percentage and RAM usage with the same formatting, thresholds,
  and refresh interval as the current segment.

## Stack

- Module crate, segment only (order 7).
- Direct `/proc/stat` delta sampling (CPU) and `/proc/meminfo` (RAM)
  on a calloop timer — replaces whatever subprocess sampling the QML
  manager does today with zero-cost file reads; the displayed numbers
  must match the current computation (transcribe the exact formula
  from `Manager.qml` at port time).

## State / IPC / keymaps

- None. Passive segment.

## Verification

- Values track `htop` within rounding over a stress run; refresh
  cadence identical to the quickshell bar side-by-side.
