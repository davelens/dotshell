# dotshell

A custom, keyboard-driven shell featuring a modular status bar and settings panel.
Built on [Quickshell](https://quickshell.outfoxxed.me), with support for Sway/i3 and Niri.

> [!INFO]
> This was made to support my own simple needs as a backend dev on Arch Linux.
> I chose to open source this for the few interested souls looking for something similar.

## Features

- Modular status bar with drop-in modules:
  - battery
  - bluetooth
  - brightness
  - clock
  - display
  - media - Play/pause toggles for music
  - notifications
  - volume
  - wireless
  - workspaces
  - ...
- Workspace support for Sway/i3 and Niri compositors
- Settings panel with basic profile management
- Keyboard-driven navigation throughout
- Catppuccin Mocha color scheme - About 50% hardcoded for now.

## Dependencies
There's quite a few you will need to install, seeing as this is mostly a personal setup.
Though I dare say most of them are common, and widely used.

| Dependency | Packages | Reason |
|---|---|---|
| Quickshell | `quickshell` | The core runtime |
| Compositor | `sway` or `niri` | Workspace detection |
| Bluetooth tools | `bluez`, `bluez-utils` | GUI connection management |
| Network management | `networkmanager` | GUI connection management |
| Brightness tools | `brightnessctl`, `ddcutil` | Backlight control via slider |
| Audio stack | `pipewire`, `wireplumber` | Volume/audio integration |
| Fonts | `otf-commit-mono-nerd`, `ttf-dejavu` | Font + nerd icons used in panels |
| Notifications CLI | `libnotify` | Catch and display notifications |

## Installation

Install the dependencies above, then clone the repo to `~/.config/dotshell`:
```sh
git clone https://github.com/davelens/dotshell.git ~/.config/dotshell
```

### If you're on Arch Linux

The script I use to install this is included in `setup/init.sh`.
It installs dependencies via `pacman` and `paru`, and configures systemd.

Clone the repository wherever and run the setup script:

```sh
git clone https://github.com/davelens/dotshell.git
cd dotshell
bash setup/init.sh
```

The setup script will:
1. Install Quickshell and all dependencies via `pacman`/`paru`
2. Configure `i2c-dev` for external monitor brightness control (ddcutil)
3. Symlink the repo to `~/.config/dotshell`
4. Enable and start a systemd user service for Quickshell
5. Install a desktop entry for the settings panel

If you need external monitor brightness control you will need a reboot to refresh the i2c group membership.

## Toggling window panels

dotshell provides IPC targets for Quickshell to call from the command line.
Useful for binding to keymaps in a window manager:
```sh
qs ipc call <target> <command> [args]
```

| Target | Command | Description |
|---|---|---|
| `settings` | `toggle` | Toggle the settings panel |
| `settings` | `show` | Open the settings panel |
| `settings` | `hide` | Close the settings panel |
| `settings` | `showCategory <id>` | Open the settings panel at a specific category |
| `bar` | `toggle` | Toggle bar focus mode |
| `popup` | `toggle <name>` | Toggle a popup by name (e.g. `volume`, `bluetooth`, `brightness`) |
| `popup` | `close` | Close the active popup |
| `notifications` | `toggle` | Toggle the notification panel |
| `notifications` | `show` | Open the notification panel |
| `notifications` | `hide` | Close the notification panel |
| `notifications` | `clearAll` | Clear the notification history |
| `idle` | `toggle` | Toggle idle inhibition |
| `idle` | `enable` | Prevent system idle/sleep |
| `idle` | `disable` | Allow system idle/sleep |
| `idle` | `state` | Print current inhibition state |
| `profile` | `list` | List all profile names |
| `profile` | `current` | Print the active profile name |
| `profile` | `enable <name>` | Switch to a profile by display name |

## License

[MIT](LICENSE)
