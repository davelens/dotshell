[Back to wiki](./index.md)

# Setup and uninstall

`setup/init.sh` detects Arch or Void Linux and installs the matching packages
and service:

- Shared module dependencies include Bluetooth, brightness and DDC tools,
  NetworkManager, PipeWire/WirePlumber, screen recorders, fonts, libnotify,
  ffmpeg, `jq`, and desktop-file-utils.
- Arch uses `pacman` for repository packages, `paru` for Quickshell, and the
  `setup/quickshell.service` systemd user unit.
- Void uses XBPS (Quickshell is in the official repository), enables
  `bluetoothd`, adds the user to `network` and `bluetooth`, and installs
  `setup/quickshell.run` as
  `~/.config/service/quickshell/run`. This expects the turnstile/runit user
  service tree configured by the Void dotsys bootstrap. The run script waits
  for turnstile's Wayland and D-Bus environment before starting Quickshell.
- External-monitor brightness setup adds the user to `i2c` when that group
  exists, loads `i2c-dev`, and persists it under `/etc/modules-load.d/`.
- Symlinks: repo → `~/.config/dotshell`, `bin/dshell` →
  `~/.local/bin/dshell`, completion →
  `$XDG_DATA_HOME/bash-completion/completions/dshell`.
- A `quickshell-settings.desktop` entry opens the settings panel through IPC.
- Module binaries in `modules/*/bin/` are symlinked separately by
  `ModuleRegistry` at shell startup, not by init.sh.

Mako must not run — the notifications module is its own daemon.

`setup/uninstall.sh` detects the same distributions and reverses the matching
service, symlinks, profile data, desktop entry, runtime logs, and Quickshell
package after confirmation.
