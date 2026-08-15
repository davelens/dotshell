# display — Rust rewrite plan

Ports `modules/display/` (Button + Popup + Settings, ~692 lines QML).
Monitor layout and primary-display selection.

## Feature parity

- Popup: connected displays, primary-display selection, and a
  "Configure" link that directly calls
  `OverlayManager.open("settings", { category: "display" })` in process.
- Settings: fetch connected outputs through the core `Compositor`
  abstraction, edit and apply per-output positions, and select the primary
  display.
- Primary selection calls `ScreenManager::set_primary` (core-owned
  `screens.json`, stable id `model:serialNumber`) — bar, settings panel,
  and popup fallback anchor follow it, exactly as documented in the
  compositor wiki page.
- Settings page preserved as-is.

## Stack

- Module crate with button + popup + settings; no module-owned persisted
  configuration.
- Compositor operations go through the core trait (`apply_position`,
  `fetch_outputs`) — sway via `swayipc-async`, niri via its JSON socket.
  The module contains zero `swaymsg`/`niri` strings (same rule as today).

## IPC

- No module-owned verbs. The popup's settings jump is an in-process overlay
  call, not settings IPC.

## Keymaps

- Popup: `PopupBase` standard set (`Escape`/`q`/`Ctrl+[`,
  `Ctrl+n`/`Ctrl+p`); the Configure link and output rows are focus-ring
  widgets activated with `Space`/`Return`/`Enter`.

## Verification

- Open Configure from the popup and confirm settings opens directly on the
  display category; reposition an external monitor on sway and on niri;
  change primary and confirm the bar migrates screens live; verify
  `screens.json` content is identical to the quickshell version's output.
