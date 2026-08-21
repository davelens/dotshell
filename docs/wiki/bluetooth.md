[Back to wiki](./index.md)

# Bluetooth

The Bluetooth module controls the adapter and manages nearby devices from the
status bar popup or settings. Quickshell's BlueZ integration is the source of
truth; command-line tools are used only for state-changing operations.

`modules/bluetooth/Manager.qml`

## Device workflow

`Bluetooth.devices.values` supplies connected, known, and discovered devices.
A device is known when BlueZ reports it as paired, bonded, or trusted.

Selecting a device performs one serialized operation through
`modules/bluetooth/bin/bluetooth-device`:

- New device: pair, trust, then connect.
- Known device: trust, then connect.
- Connected device: disconnect.
- Forget: disconnect when necessary, then remove the BlueZ record.

The helper validates Bluetooth addresses, stops pair/connect sequences on the
first failure, treats BlueZ failures written to stdout as errors, and times out
each command after 30 seconds by default. Set `BLUETOOTHCTL_TIMEOUT_SECONDS` to
adjust that hardware-dependent limit.

No automatic pairing agent is installed. Devices requiring PIN or passkey
interaction can therefore fail visibly instead of being accepted without an
explicitly constrained pairable window.

## Discovery

Opening `modules/bluetooth/Popup.qml` requests continuous discovery; closing it
always stops the owned scan, including a scan whose BlueZ confirmation arrives
late. If BlueZ ends discovery while the popup remains open, the manager starts
it again. This prevents a leaked scan from degrading Bluetooth audio.

`modules/bluetooth/Settings.qml` starts discovery manually and stops it after
ten seconds.

## Radio power

The module changes the kernel radio block directly:

- Off: `rfkill block bluetooth`.
- On: `rfkill unblock bluetooth`.

After unblocking, it makes up to three delayed `bluetoothctl power on` attempts
if BlueZ does not enable the adapter itself. The requested on/off preference is
stored profile-independently in Bluetooth module state and restored when the
shell next starts, so persistence does not depend on systemd-rfkill and also
works on Void Linux.

## Errors and UI state

Device failures appear beside the affected device. Radio and discovery failures
appear as global Bluetooth errors. While an operation is active, conflicting
controls are disabled and the row reports pairing, connecting, disconnecting,
or forgetting state.

The status bar and settings read native adapter/device notifications rather
than polling or optimistically changing connection state.
