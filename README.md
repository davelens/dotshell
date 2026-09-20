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

Standalone Claude Code is discovered automatically. Interactive Pi requires the
optional `dotshell-agent-state` extension below; headless Pi workers are ignored.
Start OpenCode with the bundled `oc` wrapper (installed at shell startup).
Discovery polls every 10 seconds.

#### Optional Pi activation (manual, on each monitored machine)

The extension lives in [pi-config](https://github.com/davelens/pi-config) at
`extensions/dotshell-agent-state/index.ts`, not in dotshell. Pi auto-loads it
when that repo is the active agent directory (`PI_CODING_AGENT_DIR`). Run
`/reload` in each open Pi session after installing or updating it; restarting
dotshell alone does not load Pi extensions. Requires Pi's `ctx.mode` and
`session_start`/`session_shutdown` lifecycle API (verified against Pi 0.86.1).

The extension atomically publishes private, per-PID records under
`${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/dotshell-agent-state` and
removes its record on shutdown or session replacement. Pi and dotshell must
share that environment; `PI_AGENT_STATE_DIR` can override the directory for both.
Discovery checks PID start ticks, boot identity, and the exact session header ID;
it never guesses ownership from cwd or file age. Unregistered, stale, or invalid
records are omitted. Nonpersistent (`--no-session`) sessions have an idle row
with a blank title. New persistent sessions are omitted until Pi first flushes
their file (normally after an assistant message), then appear automatically.

The latest nonblank session name takes precedence over the first user prompt.
Full normalized names survive transport, subject to the 64-KiB snapshot limit;
unnamed prompt previews retain an 80-character limit. Bar elision is visual only.
Existing status inference is unchanged. Remote
monitoring needs the updated module and extension activation on the remote host
as well; deployment and activation are separate manual steps, not part of setup.

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
