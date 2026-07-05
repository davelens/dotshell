# wireless — Rust rewrite plan

Ports `modules/wireless/` (Manager + Button + Popup + Settings,
~1062 lines QML). Wi-Fi status, network list, connect/disconnect,
throughput readout.

## Feature parity

- Bar button: connection state + signal icon.
- Popup: radio on/off toggle, scan/rescan, network list
  (SSID/signal/security/active), connect (secured networks prompt via
  `PasswordInput`), disconnect, saved-connections awareness, rx/tx
  throughput readout.
- Settings page unchanged.

## Stack

- Module crate with manager + button + popup + settings (order 10s
  range — keep manifest value).
- **Keep `nmcli`** as the backend (`collect_output`, argv arrays,
  terse `-t` output parsing) — exact commands preserved:
  `nmcli -t radio wifi`, `radio wifi on|off`,
  `-t -f NAME,TYPE connection show`,
  `-t -f NAME,TIMESTAMP connection show --active`,
  `-t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list [--rescan yes]`,
  `dev disconnect wlan0`, plus `nmcli dev wifi connect` for joins.
  NetworkManager's DBus API via zbus is the cleaner long-term
  backend, but nmcli parity is bit-exact and zero-risk; note the
  swap as a follow-up behind the module's backend seam.
- Throughput: read `/sys/class/net/wlan0/statistics/{rx,tx}_bytes`
  directly on the poll timer (drops the `cat` subprocess). The
  hardcoded `wlan0` is current behavior; keep it (candidate future
  fix, not part of this port).

## State

- Same state file under the module id, adapter mode, same defaults.

## Keymaps

- Popup: `Escape`/`q`/`Ctrl+[` close; `Ctrl+n`/`Ctrl+p` through
  toggle/list/fields; network rows `Space`/`Return`/`Enter` to
  connect/disconnect; `PasswordInput` keeps its text-field keys +
  submit on `Return`.

## Verification

- Join a WPA2 network keyboard-only (prompt, connect, active marker);
  radio off/on; throughput numbers match
  `cat /sys/class/net/wlan0/statistics/*_bytes` deltas.
