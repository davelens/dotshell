[Back to core](./index.md)

# Compositor integration

Core abstraction so modules never hardcode `swaymsg`/`niri msg`.

`core/Compositor.qml`

## Detection

`resolvedBackend` is `"sway"` when `SWAYSOCK`/`I3SOCK` is set,
`"niri"` for `NIRI_SOCKET`, and defaults to `"sway"` otherwise — but
then `detected` is false and every helper no-ops with a warning instead
of firing `swaymsg` blindly.

## Helpers

| Function | sway | niri |
| --- | --- | --- |
| `setTransform(name, t)` | `swaymsg output … transform` | `niri msg output … transform` |
| `focusWindow(appId)` | `swaymsg [app_id=…] focus` | `niri msg action focus-window --app-id` |
| `applyPosition(name, x, y)` | `swaymsg output … pos` | `niri msg output … position set` |
| `fetchOutputs()` | `swaymsg -t get_outputs` | `niri msg -j outputs` |

Async results come back via signals: `outputsFetched(json)`,
`positionApplied(success)`.

Related but outside the shell: `dshell wallpaper restore` does its own
compositor detection (swaymsg bg vs managing `swaybg`) because it runs
at compositor startup, before the shell.

## Primary screen

`core/ScreenManager.qml` owns primary-display selection
(`screens.json`, core-owned state): stable id `model:serialNumber`,
resolved against connected screens with first-screen fallback. The
display module's UI calls `ScreenManager.setPrimary`; the statusbar,
settings panel, and popup fallback anchor all follow `primaryScreen`.
