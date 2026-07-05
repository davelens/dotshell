# brightness — Rust rewrite plan

Ports `modules/brightness/` (Manager + Button + Popup, ~396 lines
QML). Backlight control for the laptop panel plus DDC/CI external
monitors.

## Feature parity

- Laptop backlight via `brightnessctl -m -c backlight` (enumerate) and
  `brightnessctl -d <device> set <n>%` — subprocesses kept verbatim
  (brightnessctl handles logind seat permissions; no reason to go
  direct-sysfs for writes).
- External monitors via `ddcutil detect --brief`, `getvcp 10 --brief`,
  `setvcp 10 <n>` — kept verbatim, including the display-number
  addressing.
- Popup: one slider per detected display, current percentages loaded
  on open.
- Bar button opens the popup; `dshell popup toggle brightness` works
  bar-button or not (stemless fallback anchor).

## Stack

- Module crate with button + popup (order 50); no settings page.
- `collect_output` for all brightnessctl/ddcutil calls (argv arrays,
  ADR-0001).
- Debounce `setvcp` writes (ddcutil is slow; coalesce slider drags to
  the trailing value) — matches the current debounce behavior.
- Stay in sync with the `XF86MonBrightness*` binds (which call
  `brightnessctl` directly, outside the shell): `notify` inotify watch
  on `/sys/class/backlight/*/brightness` updates the slider/button
  state. DDC monitors have no change events; re-read VCP 10 on popup
  open, as today.

## State / IPC

- None persisted; no module-owned IPC verbs.

## Keymaps

- Popup: `Escape`/`q`/`Ctrl+[` close, `Ctrl+n`/`Ctrl+p` between
  sliders; `FocusSlider` per display — `h`/`Left` decrease,
  `l`/`Right` increase. Identical step sizes.

## Verification

- Slider moves adjust real brightness (laptop + DDC); XF86 keys move
  the laptop slider while the popup is open; drag a DDC slider fast →
  one final setvcp, no queue buildup.
