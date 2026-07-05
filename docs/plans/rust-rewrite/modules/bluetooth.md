# bluetooth — Rust rewrite plan

Ports `modules/bluetooth/` (Manager + Button + Popup + Settings,
~826 lines QML). Device pairing/connection management, today built on
parsing `bluetoothctl` stdout.

## Feature parity

- Bar button: adapter power state + connected-device indicator.
- Popup: adapter power toggle, scan (bounded, 10s today), paired /
  connected / discovered device lists, per-device connect and
  disconnect.
- Settings page: current options preserved as-is.
- IPC: none of its own (popup opens via bar button or
  `dshell popup toggle bluetooth`).

## Stack

- Module crate with button + popup + settings components (order 20).
- **Replace `bluetoothctl` parsing with the BlueZ DBus API via
  `zbus`** — the one place this plan intentionally swaps backend, and
  it is strictly more reliable than scraping interactive-tool output:
  - `org.freedesktop.DBus.ObjectManager` on `org.bluez` for device
    enumeration (replaces `devices` / `devices Paired` /
    `devices Connected`).
  - `Adapter1.Powered` (replaces `power on/off`),
    `StartDiscovery`/`StopDiscovery` + a 10s calloop timer (replaces
    `--timeout 10 scan on` / `scan off`).
  - `Device1.Connect()`/`Disconnect()` (replaces
    `bluetoothctl disconnect <addr>`).
  - `InterfacesAdded`/`Removed` + `PropertiesChanged` signals drive
    the UI — no refresh polling.
- Behavior contract stays identical; only the transport changes.
  `bluetoothctl` remains uninvolved.

## State

- Same state file(s) under the module id, adapter-mode struct with
  identical fields and defaults.

## Keymaps

- Popup: standard `PopupBase` set — `Escape`/`q`/`Ctrl+[` close,
  `Ctrl+n`/`Ctrl+p` focus next/previous; device rows are
  `FocusListItem`s activated with `Space`/`Return`/`Enter`.
- Settings page: standard `SettingsPage` widget keys.

## Verification

- Power toggle, scan, connect/disconnect a headset from the popup;
  compare device lists with `bluetoothctl devices`; pull the adapter
  (rfkill) → UI degrades gracefully via signals.
