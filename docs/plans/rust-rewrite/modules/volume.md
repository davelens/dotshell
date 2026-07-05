# volume — Rust rewrite plan

Ports `modules/volume/` (Button + Popup, ~193 lines QML; no manager —
it sits directly on `Quickshell.Services.Pipewire` today).

## Feature parity

- Bar button: default sink volume/mute icon states (󰕾 ramp, muted
  variant).
- Popup: volume `FocusSlider` + mute toggle for the default sink;
  live updates while open.
- Must reflect **external** changes instantly — the `XF86Audio*` keys
  run `pactl set-sink-volume/mute` outside the shell, and today the
  bar reacts through PipeWire events. That subscription is part of
  the keymap-parity contract.

## Stack

- Module crate with button + popup (order 60).
- **`libpulse-binding`** against pipewire-pulse: default sink
  introspection, `set_sink_volume`/`set_sink_mute`, and the subscribe
  API for change events. Chosen over raw `pipewire-rs` because the
  pulse API is a fraction of the surface, battle-tested, and speaks
  the exact protocol the `pactl` keybinds use — state can never
  disagree with the binds. Runs on its own mainloop thread, events
  funneled into calloop.
- If a native-PipeWire need appears later (per-node routing), swap
  behind the module's `AudioBackend` seam; the UI doesn't care.

## State / IPC

- None persisted; popup reachable via `dshell popup toggle volume`
  (generic `popup` target), stemless fallback rules apply when the
  button is disabled.

## Keymaps

- Popup: `Escape`/`q`/`Ctrl+[` close; slider `h`/`Left` down,
  `l`/`Right` up (same step as today); mute toggle via
  `Space`/`Return`/`Enter`; `Ctrl+n`/`Ctrl+p` between widgets.
- External: all four `XF86Audio*` binds keep working untouched and
  the UI follows within one event.

## Verification

- Popup slider vs `pactl get-sink-volume` agreement; XF86 keys while
  popup open → slider moves; mute from a headset button → icon
  flips.
