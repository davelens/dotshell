# dshell

Command-line control for [dotshell](../README.md), suitable for terminals and
window-manager keybindings.

## Usage

[Setup](../setup/init.sh) symlinks `dshell` into `$XDG_BIN_HOME` (default:
`~/.local/bin`) and installs Bash completion under
`$XDG_DATA_HOME/bash-completion/completions` (default: `~/.local/share`). Add the
binary directory to your `PATH`. Requires Bash and `jq`; IPC commands also need
`qs` and a running dotshell instance.

```sh
dshell --help
dshell settings --help
dshell settings toggle
dshell display text-size 14
dshell theme set catppuccin-mocha
```

Use a command group or prefix with `--help` to list its subcommands. Help and
completion reflect the currently installed modules.

## Commands

Alternatives below are separated by commas; `<arg>` is required and `[arg]` is
optional. Prefix every command with `dshell`.

| Command | Subcommands | Purpose |
|---|---|---|
| `status-bar focus` | `toggle`, `enable`, `disable`, `state` | Status bar keyboard focus |
| `profile` | `list`, `current`, `set <name>` | Profiles |
| `settings` | `toggle`, `open`, `close`, `show-category <id>` | Settings panel |
| `theme` | `list`, `current`, `set <name>`, `refresh` | Theme selection and GTK CSS regeneration |
| `ai-agents-monitor` | `current`, `listen` | Local agent snapshot or snapshot stream |
| `bluetooth` | `toggle` | Bluetooth popup |
| `display` | `toggle`, `text-size [px]` | Display popup; query/set text size (9–20px) |
| `idle-inhibitor` | `enable`, `disable`, `toggle`, `state` | Idle inhibition |
| `notifications` | `toggle`, `open`, `close` | Notification panel |
| `notifications` | `dismiss <id>`, `clear-all`, `listen` | Dismiss, clear history, or stream new local notifications |
| `notifications remote` | `set <host>`, `clear` | Remote notification SSH host |
| `power` | `toggle`, `open`, `close` | Power menu |
| `screen-recording files` | `toggle`, `open`, `close` | Captured-file browser |
| `system-updates` | `toggle` | Updates popup |
| `volume` | `toggle` | Volume popup |
| `wallpaper browser` | `toggle`, `open`, `close` | Wallpaper browser |
| `wallpaper` | `set <path>`, `restore [fallback]` | Set wallpaper or restore saved wallpaper |
| `wireless` | `status`, `toggle` | Active network connections or Wi-Fi popup |

There are no compatibility aliases for removed command names. Failed commands
report `error: …` on stderr and exit nonzero; boolean state queries print
`true` or `false`.

### Themes and saved state

Configuration is read from `${XDG_CONFIG_HOME:-$HOME/.config}/dotshell`; data
lives in `${XDG_DATA_HOME:-$HOME/.local/share}/dotshell`. Theme JSON files in the
data directory's `themes/` override bundled [`themes/`](../themes/) by name.

`theme set` regenerates GTK 4 CSS when switching themes. Use `theme refresh`
after changing a theme through settings or editing its JSON. See
[theming](../docs/wiki/core/theming.md) for tokens and typography.

Persisted reads such as profile/theme queries work without the shell running.
`wallpaper restore` also works before shell startup, using `swaymsg` on Sway or
`swaybg` otherwise. Runtime queries and mutations generally use Quickshell IPC.

### Remote agent snapshots

```sh
dshell ai-agents-monitor current # one local snapshot
dshell ai-agents-monitor listen  # stream after each completed discovery poll
```

Both use the internal `agents` IPC target with `--any-display`, allowing queries
from non-graphical SSH sessions. Configure subscriptions under
**Settings → AI Agents Monitor** on the receiving machine.

The subscription fetches an initial snapshot, then listens over one persistent
SSH connection. It uses BatchMode, disables forwarding, and preserves SSH
host-key policy; configure non-interactive authentication and known hosts first.
Ports and jump hosts come from your SSH configuration, so existing Tailscale
aliases or MagicDNS names work too.

Remote agents are labelled by source host. Staleness is checked every 10 seconds;
imported agents are dropped once no newer snapshot has arrived for over 60
seconds. Disconnected streams are retried on a five-second timer.

Each exported agent contains only provider, project name, status, and session
title—not PIDs, working-directory paths, or ports. Snapshots also carry version,
readiness, and timestamp metadata. Imported agents are never re-exported, so
machines can monitor each other without feedback loops.

For notification subscriptions, see [remote notifications](../docs/wiki/api/remote-notifications.md).

## Completion and extensions

[`dshell`](dshell) owns core registrations, dispatch, help, and completion. On
every invocation—including `dshell --complete`—it sources installed
`modules/<module-id>/dshell/init.sh` files from the configuration directory.
Extensions only register groups/commands and define local CLI functions.
Removing a module removes its commands; no manifest or setup change is needed.

[`dshell-completion.bash`](dshell-completion.bash) delegates to that registry.
After changing completion, open a new terminal or source the file again.
See [CLI internals](../docs/wiki/api/dshell-cli.md) for registration helpers,
argument completion sources, and IPC feedback conventions.
