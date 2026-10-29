# dotshell

A modular, keyboard-driven desktop shell for Sway and Niri, built on [Quickshell](https://quickshell.outfoxxed.me). 

This reflects my personal setup for my Arch and Void Linux machines. 

## Screenshots

### Status bar

Custom icons, fixed workspaces:

![Status bar with custom icons](https://github.com/user-attachments/assets/26c0fcad-989b-40b5-bfd4-edab2a71aa81)

Dots, fixed workspaces:

![Status bar with dots](https://github.com/user-attachments/assets/756c45e6-2ffe-4ecd-903e-eadc1ea8f252)

Numbers, autodetected workspaces:

![Status bar with numbered workspaces](https://github.com/user-attachments/assets/495c2507-36d5-412f-95f5-2a8b93adba51)

### Settings

![Settings panel](https://github.com/user-attachments/assets/012ece19-c5ba-4378-86c6-3cf39541acd6)

### System updates

![System updates panel](https://github.com/user-attachments/assets/5b2baa8d-030f-4119-9cac-a728b6f9fdd4)

## Features

- Configurable status bar with drop-in modules and keyboard focus mode.
- Keyboard-driven settings and profile management.
- Live-switching JSON themes: Catppuccin, Everforest, Nord, Rosé Pine, and
  Tokyo Night, with [user overrides](docs/wiki/core/theming.md).

| Module | Provides |
|---|---|
| `ai-agents-monitor` | OpenCode, Claude Code, and interactive Pi session status; remote monitoring over SSH |
| `battery` | Charge and AC status |
| `bluetooth` | Device discovery, pairing, and connections |
| `clock` | Date and time |
| `display` | Monitor layout, scaling, text size, and internal/external brightness |
| `idle-inhibitor` | Prevent compositor idle actions |
| `media` | Media playback controls |
| `notifications` | Desktop notifications, history, do-not-disturb, and remote subscriptions |
| `power` | Lock, suspend, logout, reboot, and shutdown |
| `screen-recording` | Screenshots, screencasts, and captured-file browsing |
| `system-load` | CPU and memory usage |
| `system-updates` | Native repository, community package, and Flatpak updates where supported |
| `volume` | Audio output/input levels, devices, and streams |
| `wallpaper` | Wallhaven browsing, downloads, and wallpaper selection |
| `wireless` | Wi-Fi scanning, connections, and throughput |
| `workspaces` | Sway/Niri workspace indicators and switching |

### AI agent monitoring

Agents push their status to the shell over a Unix socket at
`$XDG_RUNTIME_DIR/dotshell-agents.sock`, one JSON line per change:

```json
{"provider": "pi", "pid": 1234, "status": "busy", "cwd": "/path", "title": "..."}
```

`provider` is `opencode`, `claude-code`, or `pi`; `status` is `busy`, `idle`,
`error`, `input`, or `gone` (removes the agent). Pi and OpenCode keep their
connection open, and closing it removes the agent. Claude Code hooks send
one-shot lines with `"oneshot": true`. Once a minute the shell rescans Claude
session files: Claude sessions started before the shell appear as idle, and
sessions that ended without a `SessionEnd` hook are dropped.

Each agent needs a sender, set up manually on each monitored machine:

- **Pi:** the `dotshell-agent-state` extension in
  [pi-config](https://github.com/davelens/pi-config). Only interactive (TUI)
  sessions report; run `/reload` in open sessions after installing or updating
  it.
- **OpenCode (2.x):** the `dotshell-agents/` plugin directory in the OpenCode
  `plugins/` config directory (kept in the dotfiles repo). Its `tui.js` runs in
  each TUI process, so closing the TUI removes the agent even though the
  background service keeps running.
- **Claude Code:** register `bin/claude-hook` (symlinked to
  `${XDG_BIN_HOME:-$HOME/.local/bin}/claude-hook`) in `settings.json` for
  `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
  `PermissionRequest`, `Stop`, `StopFailure`, and `SessionEnd`. It sends with
  `ncat`, and skips Claude processes driven by Pi so Pi stays the single
  counted agent.

Remote monitoring needs the same senders on the remote host.

To monitor another dotshell machine, enter its SSH alias under
**Settings → AI Agents Monitor**. This uses non-interactive SSH with your usual
SSH configuration, including Tailscale hosts. See the
[CLI reference](bin/README.md#remote-agent-snapshots) for snapshot commands and
transport details.

## Installation

Run setup as your desktop user, **not root**, from a checkout outside
`~/.config/dotshell`; setup creates that symlink for you:

```sh
git clone https://github.com/davelens/dotshell.git
cd dotshell
bash setup/init.sh
```

- **Arch:** requires `sudo`, `paru`, and a configured graphical session. Installs
  packages through `pacman`/`paru` and enables a systemd user service.
- **Void:** requires `sudo`, elogind, and turnstile's runit backend, as configured
  by [dotsys](https://github.com/davelens/dotsys). Installs through XBPS; the
  bundled user service requires **Sway** to launch dotshell in the graphical
  session, even though the shell itself also supports Niri.

Setup installs Quickshell and shared module dependencies, configures `i2c-dev`
for external brightness, and installs the service, CLI, Bash completion, and
settings desktop entry. Exact package lists live in the
[Arch](setup/platforms/arch.sh) and [Void](setup/platforms/void.sh) adapters;
setup does not provision a complete desktop session or every optional tool.

Stop any existing notification daemon (such as Mako) before using dotshell's
notifications. Log out and back in after setup adds you to device-access groups.

Services default to the Vulkan renderer; use OpenGL if needed. See
[setup documentation](docs/wiki/setup.md) for renderer overrides, service
behavior, and uninstall details.

## CLI and documentation

- [`dshell` reference](bin/README.md) — commands, completion, and module extensions.
- [Project wiki](docs/wiki/index.md) — architecture, configuration, and behavior.

## Tests

```sh
bash tests/run.sh
```

Requires `jq`; uses `shellcheck` when installed. The suite includes shell checks,
JSON validation, and fixture tests. Setup/uninstall tests use temporary homes
and fake host-changing commands. Pi extension lifecycle checks live in pi-config.
CI runs the full suite on Ubuntu and the setup/uninstall harness in Arch and
Void containers.

## License

[MIT](LICENSE)
