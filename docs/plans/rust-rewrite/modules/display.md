# display — Rust rewrite plan

Ports `modules/display/` (Config + Button + Popup + Settings,
~736 lines QML). Monitor layout, rotation/transform, and primary
display selection.

## Feature parity

- Popup: connected outputs (via the core `Compositor` abstraction —
  `fetch_outputs`), per-output transform/rotation, position
  application, primary-display selection.
- Primary selection calls `ScreenManager::set_primary` (core-owned
  `screens.json`, stable id `model:serialNumber`) — bar, settings
  panel, and popup fallback anchor follow it, exactly as documented in
  the compositor wiki page.
- The "open display settings" jump: today it shells out to
  `qs ipc call settings showCategory display`; becomes a direct
  in-process `OverlayManager.open("settings", context)` call — same
  observable behavior, one less subprocess.
- Settings page preserved as-is.

## Stack

- Module crate with button + popup + settings + a `Config` unit
  (ports `Config.qml`'s persistence role, adapter-mode state under the
  `display` id, same schema).
- All compositor mutations go through the core trait (`set_transform`,
  `apply_position`, `fetch_outputs`) — sway via `swayipc-async`, niri
  via its JSON socket. The module contains zero `swaymsg`/`niri`
  strings (same rule as today).

## IPC

- No module-owned verbs.

## Keymaps

- Popup: `PopupBase` standard set (`Escape`/`q`/`Ctrl+[`,
  `Ctrl+n`/`Ctrl+p`); output rows and action buttons are focus-ring
  widgets activated with `Space`/`Return`/`Enter`; any `Dropdown`
  (transform selection) keeps `j`/`k`/arrows + `Escape`.

## Verification

- Rotate an external monitor from the popup on sway and on niri;
  change primary → bar migrates screens live; `screens.json` content
  identical to the quickshell version's output.
