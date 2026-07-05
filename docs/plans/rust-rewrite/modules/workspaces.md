# workspaces — Rust rewrite plan

Ports `modules/workspaces/` (Manager + I3Backend + NiriBackend +
Segment + Settings, ~725 lines QML). Workspace indicator with three
display styles.

## Feature parity

- Display modes preserved (Settings page): custom icons, dots, or
  numbers; fixed workspace count vs autodetect (the README screenshot
  variants).
- Active/urgent/occupied styling identical; click (and bar-focus-mode
  activate) switches to the workspace.
- Backend selection follows the core Compositor detection
  (`SWAYSOCK`/`I3SOCK` → sway/i3, `NIRI_SOCKET` → niri; undetected →
  inert with a warning, as core dictates).

## Stack

- Module crate with manager + segment + settings, backend trait with
  two impls (mirrors `I3Backend.qml` / `NiriBackend.qml`):
  - **Sway/i3**: `swayipc-async` — `get_workspaces` on start, then
    `subscribe([Workspace])` events. Strictly better than the current
    `swaymsg -t get_workspaces` polling; state can't go stale.
    Workspace switch via `workspace number N` command on the same
    connection.
  - **Niri**: `niri msg event-stream` equivalent — long-lived
    connection to `NIRI_SOCKET` (the socket-glob fallback
    `/run/user/$UID/niri.*.sock` ports too), `stream_lines`-style
    JSON event parsing + initial `-j workspaces` snapshot; switch via
    the action socket call.

## State

- Same state file under the `workspaces` id (display mode, fixed
  count, icon map), adapter mode, same defaults.

## IPC / keymaps

- No module-owned IPC verbs. Segment `activate()` in bar focus mode
  (`Space`/`Return`/`Enter`) and click both switch workspace, as
  today. Compositor-level workspace keybinds
  (`$mod+bracketleft/right`, `$mod+Shift+1-6`) never touch the shell
  and simply keep working; the segment follows via events.

## Verification

- Switch workspaces via sway binds → segment updates instantly on
  sway and niri; all three display styles + fixed/autodetect render
  identically to quickshell side-by-side; restart the compositor
  connection (sway reload) → backend reconnects.
