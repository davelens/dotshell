# battery — Rust rewrite plan

Ports `modules/battery/` (Segment only, ~120 lines QML). Charge level
and AC adapter status; currently built on `Quickshell.Services.UPower`.

## Feature parity

- Percentage, charging/discharging/full state, icon ramp per level +
  charging variant, low-battery color treatment — identical visuals.
- Hidden on systems with no battery (desktop) — same rule as the
  UPower device absence check today.

## Stack

- Module crate, segment component only (order 110).
- UPower over `zbus`: proxy `org.freedesktop.UPower` →
  `/org/freedesktop/UPower/devices/DisplayDevice`, read `Percentage`,
  `State`, `IsPresent`, `TimeToEmpty`/`TimeToFull`; subscribe to
  `PropertiesChanged` (event-driven, zero polling). Hand-written zbus
  proxy (a dozen lines) — no extra crate needed.

## State / IPC / keymaps

- None. Passive segment in bar focus mode.

## Verification

- Plug/unplug AC: icon and state flip without polling delay; values
  match `upower -i /org/freedesktop/UPower/devices/DisplayDevice`.
