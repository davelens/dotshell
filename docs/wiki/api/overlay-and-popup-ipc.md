[Back to API](./index.md)

# Overlay and popup IPC

How full-screen overlays (panels, power menu, settings) and bar popups
are controlled externally. Designed so core holds no module knowledge —
modules stay pluggable (see `../../memory/architecture.md`).

## The overlay target

`core/OverlayManager.qml` exposes one id-addressed IpcHandler:

```
qs ipc call overlay toggle <id>   # also: open, close
```

Overlay managers self-register at startup:

```qml
Component.onCompleted: OverlayManager.register("wallpaper", "Wallpaper browser")
```

The registrations map id → human label. Labels build the feedback
strings ("Wallpaper browser opened"); the id set validates calls —
unknown ids return `error: unknown overlay '<id>'`. Registered overlays:
`notifications`, `power`, `recording`, `wallpaper` (modules) and
`settings` (core, `settings/Panel.qml`).

`dshell` maps its per-module verbs onto this target (`dshell power
toggle` → `ipc overlay toggle power`), so the CLI vocabulary stays
per-module while QML has one seam.

## Module-specific IPC verbs

Only verbs that genuinely belong to a module keep their own target:

| Target | Functions |
| --- | --- |
| `notifications` | `dismiss(id)`, `clearAll()` |
| `wallpaper` | `set(path)` |
| `settings` | `showCategory(categoryId)` |
| `idle` | `enable/disable/toggle/state` |
| `bar` | `enable/disable/toggle/state` (focus mode, `shell.qml`) |
| `popup` | `toggle(name)` |
| `theme` / `profile` | `set`, `current`, `list` (`core/GeneralSettings.qml`) |

## Popup anchoring and the stem

`core/PopupManager.qml` toggles popups by name. Anchor resolution on
IPC toggle:

1. Bar button registered for the popup (`registerButton`, called from
   `BarButton`) → anchor to the button's right edge,
   `anchoredToButton = true`.
2. No button (module disabled in the bar) → primary screen, right edge
   minus 20px (matches the 20px statusbar-to-popup gap),
   `anchoredToButton = false`.

Stem connector visibility (`core/components/PopupBase.qml`):

```
showStem = StatusbarManager.popupStem && stemEnabled && PopupManager.anchoredToButton
```

so an IPC-opened popup without its bar button never draws a stem
pointing at nothing, regardless of the global `popupStem` setting.
Stemless popups get a square top-right corner and a larger content
offset via existing bindings.

## Adding a new overlay

1. Route open state through OverlayManager: bind visibility to
   `OverlayManager.isOpen(id)`, mutate via `toggle/open/close`.
2. `Component.onCompleted: OverlayManager.register(id, label)` in the
   manager.
3. Three `COMMANDS` rows in `bin/dshell` mapping the module's CLI verbs
   to `ipc overlay <verb> <id>`.
