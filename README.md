# dotshell

A custom, keyboard-driven shell featuring a modular status bar and settings panel, built on [Quickshell](https://quickshell.outfoxxed.me)

> [!NOTE]
> This was made to support my own simple needs as a backend dev on Arch and Void Linux.
> I chose to open source this for the few interested souls looking for something similar.

## Screenshots

### Status bar

#### Custom icons, fixed workspaces
<img width="2558" height="42" alt="image" src="https://github.com/user-attachments/assets/26c0fcad-989b-40b5-bfd4-edab2a71aa81" />

#### Dots, fixed workspaces, less icons
<img width="2558" height="42" alt="image" src="https://github.com/user-attachments/assets/756c45e6-2ffe-4ecd-903e-eadc1ea8f252" />

#### Numbers, with autodetect
<img width="2558" height="42" alt="image" src="https://github.com/user-attachments/assets/495c2507-36d5-412f-95f5-2a8b93adba51" />

### Settings panel
<img width="1554" height="1141" alt="image" src="https://github.com/user-attachments/assets/012ece19-c5ba-4378-86c6-3cf39541acd6" />

### Updates panel
<img width="935" height="664" alt="image" src="https://github.com/user-attachments/assets/5b2baa8d-030f-4119-9cac-a728b6f9fdd4" />

## Features

- Modular status bar with drop-in modules:
  - battery - Charge level and AC adapter status
  - bluetooth - Device pairing and connection management
  - brightness - Backlight control for laptop and external monitors
  - clock - Date and time display
  - display - Monitor layout and scaling settings
  - idle-inhibitor - Toggle to prevent the system from going idle/sleeping
  - media - Play/pause toggles for music
  - notifications - Desktop notification history and management
  - opencode - Status indicator for running OpenCode AI agent sessions
  - power - Lock, suspend, logout, reboot, and shutdown actions
  - recording - Screenshot and screencast capture with file browsing
  - system-load - Live CPU and memory usage display
  - updates - Package update checker for native repositories, community packages, and Flatpak
  - volume - Audio output and input level control
  - wallpaper - Browse, download, and apply wallpapers via Wallhaven
  - wireless - Wi-Fi network scanning and connection management
  - workspaces - Window manager workspace indicators and switching
- Workspace support for Sway/i3 and Niri compositors
- Settings panel with basic profile management
- Keyboard-driven navigation throughout, status bar included
- Catppuccin Mocha color scheme - Not configurable yet, but you can alter `core/Colors.qml`

### Module: opencode

This module requires starting OpenCode with the `oc` binary it provides. This 
makes the status bar segment aware of OpenCode's state in real time.

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
| JSON tooling | `jq` | `dshell` state reads and completion |

## Installation

Install the dependencies above, then clone the repo to `~/.config/dotshell`:
```sh
git clone https://github.com/davelens/dotshell.git ~/.config/dotshell
```

### Arch Linux and Void Linux

The setup script detects either distribution. On Arch it installs packages via
`pacman`/`paru` and configures a systemd user service. On Void it installs
packages via XBPS and configures a turnstile-managed runit user service, matching
the session setup in [dotsys](https://github.com/davelens/dotsys).

Clone the repository wherever and run the setup script:

```sh
git clone https://github.com/davelens/dotshell.git
cd dotshell
bash setup/init.sh
```

The setup script will:
1. Install dotshell's Quickshell runtime and dependencies via `pacman`/`paru` or XBPS
2. Configure `i2c-dev` for external monitor brightness control (ddcutil)
3. Symlink the repo to `~/.config/dotshell`
4. Install the `dotshell` systemd (Arch) or turnstile/runit (Void) user service
5. Install a desktop entry for the settings panel

The Void path expects elogind for session/seat/polkit integration and
turnstile's runit backend for the user service tree at `~/.config/service`, as
configured by this author's dotsys setup. Runit supervises dotshell while Sway
launches the process into the active graphical session, allowing background
polkit requests to reach its graphical agent. If you need external monitor
brightness control, log out and back in to refresh group membership.

## CLI

dotshell ships a `dshell` CLI for controlling the shell from the command line or window manager keybinds. It is symlinked into `$XDG_BIN_HOME`, falling back to `~/.local/bin`; make sure that directory is in your `$PATH`.

```sh
dshell <command> <subcommand> [args]
```

| Command | Subcommand | Description |
|---|---|---|
| `bar` | `focus <verb>` | Bar focus mode: `toggle`, `enable`, `disable`, `state` |
| `idle` | `enable` | Enable idle inhibitor |
| `idle` | `disable` | Disable idle inhibitor |
| `idle` | `toggle` | Toggle idle inhibitor |
| `idle` | `state` | Show idle inhibitor state |
| `notifications` | `toggle` | Toggle notification panel |
| `notifications` | `open` | Open notification panel |
| `notifications` | `close` | Close notification panel |
| `notifications` | `dismiss <id>` | Dismiss a notification by id |
| `notifications` | `clear-all` | Clear notification history |
| `popup` | `toggle <name>` | Toggle a popup (e.g. `volume`, `brightness`, `wireless`) |
| `power` | `toggle` | Toggle power menu |
| `power` | `open` | Open power menu |
| `power` | `close` | Close power menu |
| `profile` | `list` | List all profiles |
| `profile` | `current` | Show active profile name |
| `profile` | `set <name>` | Switch to a profile |
| `screen-recording` | `files <verb>` | Screen recording file browser: `toggle`, `open`, `close` |
| `settings` | `toggle` | Toggle settings panel |
| `settings` | `open` | Open settings panel |
| `settings` | `close` | Close settings panel |
| `settings` | `show-category <id>` | Open settings to a specific category |
| `theme` | `list` | List available themes |
| `theme` | `set <name>` | Switch to a theme |
| `theme` | `current` | Show active theme name |
| `theme` | `refresh` | Regenerate GTK CSS for the active theme |
| `wallpaper` | `browser <verb>` | Wallpaper browser panel: `toggle`, `open`, `close` |
| `wallpaper` | `set <path>` | Set a wallpaper by file path |
| `wallpaper` | `restore [fallback]` | Restore saved wallpaper |

## License

[MIT](LICENSE)
