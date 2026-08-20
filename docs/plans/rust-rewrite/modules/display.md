# display — Rust rewrite plan

Ports the consolidated `modules/display/` manager, button, popup, scripts, and
existing monitor-layout settings page.

## Feature parity

- One bar button and popup for connected-output selection, output enable/disable,
  selected-output brightness, text size, and render scale presets.
- Normalize sway output arrays and niri output maps into one model. Output
  position, scale, and power mutations stay behind the core compositor trait.
- Keep the existing monitor-layout settings canvas and primary-display
  selection. Selecting an active output calls `ScreenManager::set_primary`, so
  the bar and popup anchor follow it.
- Never disable the final active output.
- Internal brightness uses the preferred kernel backlight; external brightness
  maps DRM connectors to DDC I2C buses, caches detection/ranges, converts the
  monitor's VCP range, and coalesces writes to one trailing value.
- General-scoped `display-general.json` owns integer `textSize` (default 14,
  range 9–20). It scales shell text and updates GTK plus existing Alacritty,
  Kitty, Ghostty, and Foot configs without creating terminal configs.

## Stack

- Module crate with manager + button + popup + settings.
- Core compositor operations: `apply_position`, `apply_scale`,
  `set_output_active`, and `fetch_outputs`; sway and niri use their native IPC
  implementations.
- Brightness and external text-size behavior remain narrow executable adapters
  invoked with argv arrays.

## IPC

- `display currentTextSize` and `display setTextSize <px>` preserve
  `dshell display text-size [px]`.
- Popup toggle remains the module's standard popup registration.

## Keymaps

- `PopupBase` standard close/navigation keys.
- Focus controls cover output selection/power, brightness, text-size notches,
  and scale presets. Button wheel changes selected brightness by 5%, or 1% at
  and below 5%.

## Verification

- Exercise internal and DDC brightness adapters with command/sysfs fakes.
- Toggle and scale outputs on sway and niri; confirm successful mutations
  refetch state and the last active output cannot be disabled.
- Reposition monitors in Settings and move primary display live.
- Set/query text size through the popup and `dshell`; verify shell, GTK, and
  existing terminal configs update without changing font families.
