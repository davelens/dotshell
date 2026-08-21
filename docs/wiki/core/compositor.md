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
| `focusWindow(appId)` | `swaymsg [app_id=…] focus` | `niri msg action focus-window --app-id` |
| `applyPosition(name, x, y)` | `swaymsg output … pos` | `niri msg output … position set` |
| `applyScale(name, scale)` | `swaymsg output … scale` | `niri msg output … scale` |
| `setOutputActive(name, active)` | `swaymsg output … enable/disable` | `niri msg output … on/off` |
| `fetchOutputs()` | `swaymsg -t get_outputs` | `niri msg -j outputs` |

Async results come back via `outputsFetched`, `positionApplied`, `scaleApplied`,
and `outputPowerApplied`. Successful scale and power changes refetch outputs.
The display manager normalizes sway's output array and niri's output map into
one model for its popup and monitor-layout settings page.

Related but outside the shell: `dshell wallpaper restore` does its own
compositor detection (swaymsg bg vs managing `swaybg`) because it runs
at compositor startup, before the shell.

## Primary screen

`core/ScreenManager.qml` owns primary-display selection
(`screens.json`, core-owned state): stable id `model:serialNumber`,
resolved against connected screens with first-screen fallback. The
display module's UI calls `ScreenManager.setPrimary`; the statusbar,
settings panel, and popup fallback anchor all follow `primaryScreen`.
Selecting an active output in the combined display popup also makes it primary;
the popup prevents disabling the final active output.

## Clamshell policy

The display module's root component keeps its manager active independently of
the bar button and popup. The manager reads login1's
`org.freedesktop.login1.Manager.LidClosed` property with an initial system-bus `gdbus call`, then follows
`PropertiesChanged` events with a long-running `gdbus monitor`. It waits for a
known lid state before applying policy.

With the lid closed and an active external output, the manager disables the
internal panel (`eDP-`, `LVDS-`, or `DSI-`). Opening the lid restores a panel
disabled or adopted by the policy. It also restores the internal panel whenever
the final external output disconnects and no output remains active, so display
handling cannot leave the session with zero outputs. Closing without an external
output leaves the internal panel enabled. Power changes use the compositor
abstraction for both sway and niri and are serialized with manual display power
controls; manual controls still reject disabling the final active output.

## Display controls

`modules/display/Manager.qml` combines output selection, power, render scale,
text size, and selected-output brightness. Internal panels use the preferred
kernel backlight through `brightnessctl`; external outputs map their DRM
connector to a cached DDC I2C bus, honor the monitor's VCP brightness range,
and coalesce slider writes. The former standalone brightness module no longer
exists.
