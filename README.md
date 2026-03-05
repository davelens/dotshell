> [!WARNING]
> I'm still in the process of porting this over until I've had a chance to test this on a fresh install.

# dotshell

A custom shell built with [Quickshell](https://quickshell.outfoxxed.me), featuring a configurable status bar with modular components and workspace support for Sway and Niri.

## Features

- Modular status bar with drop-in modules:
  - battery
  - bluetooth
  - brightness
  - clock
  - display
  - media
  - notifications
  - volume
  - wireless
  - workspaces
  - ...
- Workspace support for Sway/i3 and Niri compositors
- Settings panel with basic profile management
- Keyboard-driven navigation throughout
- Catppuccin Mocha color scheme - About 50% hardcoded for now.

## Requirements

- Arch Linux (the setup script uses `pacman` and `paru`)
- [Quickshell](https://quickshell.outfoxxed.me) (installed automatically from the AUR)
- Sway or Niri compositor

## Installation

Clone the repository and run the setup script:

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

After installation, log out and back in if you need external monitor brightness control (i2c group membership).

## IPC Commands

dotshell exposes IPC targets you can call from the command line or bind to keybindings:

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
