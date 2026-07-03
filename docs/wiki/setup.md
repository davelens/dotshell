[Back to wiki](./index.md)

# Setup and uninstall

`setup/init.sh` (Arch-specific) installs everything:

- pacman deps for modules (bluez, brightnessctl, ddcutil, networkmanager,
  pipewire/wireplumber, gpu-screen-recorder, wf-recorder, fonts,
  libnotify, ffmpeg) + `quickshell` via paru. `jq` is required by
  `dshell` (see README dependency table).
- i2c setup for external-monitor brightness: user added to `i2c` group,
  `i2c-dev` module loaded + persisted (relogin needed for the group).
- Symlinks: repo → `~/.config/dotshell`, `bin/dshell` →
  `~/.local/bin/dshell`, completion →
  `$XDG_DATA_HOME/bash-completion/completions/dshell`.
- Enables `setup/quickshell.service` (user unit, part of
  `graphical-session.target`, auto-restart on failure).
- Writes a `quickshell-settings.desktop` entry (opens the settings
  panel via IPC).
- Module binaries in `modules/*/bin/` are symlinked separately by
  `ModuleRegistry` at shell startup, not by init.sh.

Mako must not run — the notifications module is its own daemon.

`setup/uninstall.sh` reverses it (service, symlinks, profile data,
desktop entry, runtime logs, package) after confirmation.
