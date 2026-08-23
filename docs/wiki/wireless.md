[Back to wiki](./index.md)

# Wireless

The wireless module manages NetworkManager Wi-Fi from the status bar popup and
settings. Quickshell's native `Quickshell.Networking` API is the source of truth
for device state, scans, radio power, and connection operations.

Primary code: `modules/wireless/Manager.qml` · `modules/wireless/Popup.qml` ·
`modules/wireless/Settings.qml`

## Network model

`WirelessManager` converts native Wi-Fi devices and networks into a primitive
`ListModel` snapshot for the UI. Native objects remain private to the manager
and are resolved again when an action starts. Each row key contains both the
NetworkManager device name and SSID, so the same SSID on different adapters is
not treated as one action target.

Connected networks sort first, followed by signal strength, SSID, and device.
Rows expose only display and action state such as signal, security, known,
connected, and state-changing status.

## Scanning

Opening `modules/wireless/Popup.qml` enables scanning on every current Wi-Fi
device and owns that continuous scan until the popup closes. Closing the popup
also clears a pending password prompt.

Settings does not own a continuous scan. Its refresh control requests a bounded
five-second scan, after which the manager disables the scanners it enabled.
Turning Wi-Fi off or losing devices also releases their scanners.

## Radio and network actions

The radio toggle writes `Networking.wifiEnabled`; hardware-disabled and
non-NetworkManager states remain unavailable rather than being changed
optimistically. Network rows call the native operations directly:

- `connect` connects open and known networks. A new WPA-PSK, WPA2-PSK, or SAE
  network opens the inline password prompt instead.
- `connectWithPsk` passes the submitted password directly to the native network
  object. The password is never stored or put in a subprocess argument list.
- `disconnect` disconnects the selected device-qualified network.
- `forget` asks NetworkManager to remove the selected known network.

Only one radio, connect, disconnect, or forget action can run at a time.
Failures retain a typed code for backend unavailability, authentication timeout,
missing secrets, client disconnect or failure, network loss, unknown failure,
or operation timeout. Every action has a 30-second timeout, and the UI reports
failures against the affected row when possible.

Popup and settings management do not use `nmcli` for state or actions. The
separate `dshell wireless status` command only prints active connections and
does not drive this native state or perform these actions.

## Connection details and scope

Quickshell does not expose NetworkManager's activation timestamp. When the
connected network changes, the manager uses two direct `nmcli` queries to
resolve the active profile UUID and fetch its last successful activation time.
This one-shot metadata lookup drives the popup and bar-tooltip uptime; it does
not poll connection state or handle credentials.

While connected, the manager passively samples the active interface's
`/sys/class/net/<device>/statistics/rx_bytes` and `tx_bytes` counters once per
second and derives current download and upload rates. It performs no network
probe.

The module is deliberately compact: it does not provide DNS information, band
controls, ping, QR sharing, or speed tests.
