[Back to dotshell wiki](./index.md)

# Volume

The volume module controls the active audio output and input, switches default
devices, and keeps existing application streams on the selected device. It uses
Quickshell's PipeWire service for live state and direct volume changes.

`modules/volume/Popup.qml`

## Controls

The bar button reflects the default output's volume and mute state. Scrolling it
changes output volume in 5% steps, clamped to 0–100%.

The popup provides separate output and input controls:

- volume sliders from 0–100% in 2% steps;
- mute toggles and live percentages;
- default-device selectors populated from non-stream PipeWire sinks and sources.

`PwObjectTracker` binds every listed device so names and audio state remain
available for non-default devices. Default selections stay bound directly to
`Pipewire.defaultAudioSink` and `Pipewire.defaultAudioSource`, so external
changes are reflected while the popup remains open.

## Device switching

`modules/volume/bin/volume-set-default`

Selecting a device immediately updates Quickshell's preferred default and runs
`volume-set-default` with the PipeWire node id and name. The helper:

1. sets the WirePlumber default with `wpctl`;
2. when `pactl` is available, also sets the Pulse-compatible default;
3. moves active playback or recording streams to the selected device.

Only playback streams with an `application.name` are moved. EasyEffects and
unidentified processing streams are left in place to avoid rewiring a DSP graph.
If `pactl` is unavailable, the default still changes through `wpctl`, but active
streams remain on their existing device.

## State

The module persists no audio state. PipeWire/WirePlumber own defaults, volume,
and mute state; the UI reacts to their live events, including changes made by
external media-key commands.
