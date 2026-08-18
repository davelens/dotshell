[Back to wiki](./index.md)

# Setup and uninstall

`setup/init.sh` detects Arch or Void Linux and installs the matching packages
and service:

- Shared module dependencies include Bluetooth, brightness and DDC tools,
  NetworkManager, PipeWire/WirePlumber, screen recorders, fonts, libnotify,
  ffmpeg, `jq`, and desktop-file-utils.
- Arch uses `pacman` for repository packages, `paru` for the Quickshell
  runtime, and the `setup/dotshell.service` systemd user unit.
- Void uses XBPS (the Quickshell runtime is in the official repository),
  enables `bluetoothd`, adds the user to `network` and `bluetooth`, and
  installs `setup/dotshell.run` as `~/.config/service/dotshell/run`. This
  expects the elogind session and turnstile/runit user service tree configured
  by the Void dotsys bootstrap. The run script waits for turnstile's Sway,
  Wayland, and D-Bus environment, then asks Sway to launch dotshell in the
  active graphical elogind session. Runit continues to supervise its lifetime,
  while same-session polkit requests can reach the graphical agent.
- External-monitor brightness setup adds the user to `i2c` when that group
  exists, loads `i2c-dev`, and persists it under `/etc/modules-load.d/`.
- Symlinks: repo → `~/.config/dotshell`, `bin/dshell` → the
  `$XDG_BIN_HOME` directory (falling back to `~/.local/bin`), completion →
  `$XDG_DATA_HOME/bash-completion/completions/dshell`.
- A `dotshell-settings.desktop` entry opens the settings panel through IPC.
- Module binaries in `modules/*/bin/` are symlinked separately into the same
  `$XDG_BIN_HOME` directory by `ModuleRegistry` at shell startup, not by init.sh.

Module CLI extensions need no setup integration or manifest field. The installed
`bin/dshell` discovers `$CONFIG_DIR/modules/*/dshell/init.sh` on every invocation
and completion, so adding or removing a module adds or removes its CLI surface.
Extension files only register commands/groups and define local CLI functions.

Mako must not run — the notifications module is its own daemon.

## Renderer backend

Both service definitions default `QSG_RHI_BACKEND` to `vulkan`. Compared with
Qt's OpenGL backend on the reference AMD system, Vulkan reduced dotshell's
median PSS from 270.7 MB to 206.4 MB. The backend is selected before QML loads,
so changing it requires a service restart.

| Value | Use |
| --- | --- |
| `vulkan` | Default; lowest measured memory usage. |
| `opengl` | Compatibility fallback if Vulkan rendering misbehaves. |

On Arch, override the default with `systemctl --user edit dotshell.service`:

```ini
[Service]
Environment=QSG_RHI_BACKEND=opengl
```

Then run `systemctl --user restart dotshell.service` and `dshell idle-inhibitor enable`.
Remove the override, or change it back to `vulkan`, to restore the default.

On Void, `setup/dotshell.run` preserves an existing `QSG_RHI_BACKEND` from the
turnstile environment and otherwise supplies `vulkan`; set that environment
entry to `opengl` and restart the runit service to use the fallback.

`setup/uninstall.sh` detects the same distributions and reverses the matching
service, symlinks, profile data, desktop entry, runtime logs, and Quickshell
runtime package after confirmation.
