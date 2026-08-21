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
unknown ids return `error: unknown overlay '<id>'`. Keyboard/IPC opens snapshot
the compositor's focused output; opens originating from a bar button or an
existing panel pass that surface's screen explicitly. Registered overlays:
`notifications`, `power`, `screen-recording`, `wallpaper` (modules) and
`settings` (core, `settings/Panel.qml`).

`dshell` maps its per-module verbs onto this target (`dshell power
toggle` → `ipc overlay toggle power`, `dshell screen-recording files toggle` →
`ipc overlay toggle screen-recording`), so the CLI vocabulary stays per-module
while QML has one seam.

## Module-specific IPC verbs

Only verbs that genuinely belong to a module keep their own target:

| Target | Functions |
| --- | --- |
| `notifications` | `dismiss(id)`, `clearAll()` |
| `wallpaper` | `set(path)` |
| `display` | `setTextSize(px)`, `currentTextSize()` |
| `settings` | `showCategory(categoryId)` |
| `idle` | `enable/disable/toggle/state` |
| `bar` | `enable/disable/toggle/state` (focus mode, `shell.qml`) |
| `popup` | `toggle(name)` |
| `theme` / `profile` | `set`, `current`, `list` (`core/GeneralSettings.qml`) |

These are internal names, not public command groups. For example,
`dshell status-bar focus toggle` maps to the `bar` target,
`dshell idle-inhibitor toggle` maps to `idle`, and `dshell bluetooth toggle`,
`dshell display toggle`, `dshell system-updates toggle`, `dshell volume toggle`,
and `dshell wireless toggle` map to `popup.toggle(name)`. `dshell display
text-size [px]` queries or mutates the display target directly.

Popup names are validated against modules whose manifests declare a popup
component (`ModuleRegistry.getPopupModuleIds()`). An unknown name returns
`error: unknown popup '<name>'` without closing an overlay or changing popup
state.

Bluetooth is module-specific: opening its popup clears prior connection errors
without auto-scanning; closing it stops a scan explicitly started by the user.

## Popup anchoring and the stem

`core/PopupManager.qml` snapshots a target screen whenever a popup opens:

1. A bar click passes its button's screen and right edge directly,
   `anchoredToButton = true`.
2. A keyboard/IPC toggle uses the compositor's focused output, positions
   against its right edge minus 20px, and sets `anchoredToButton = false`.

Sway focus comes from Quickshell's I3 model. Niri focus is initialized with
`niri msg -j focused-output` and refreshed from its event stream.

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
3. Register the module's three CLI verbs in
   `modules/<module-id>/dshell/init.sh`, mapping them to `ipc overlay <verb>
   <id>`. The file is discovered on each `dshell` invocation/completion; no
   manifest or setup declaration is needed.
