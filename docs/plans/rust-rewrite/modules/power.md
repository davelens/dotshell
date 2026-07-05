# power — Rust rewrite plan

Ports `modules/power/` (Manager + Button + Overlay + Settings,
~637 lines QML). Full-screen power menu.

## Feature parity

- Overlay (root component, `PanelBase`, registered as overlay
  `power`): lock / suspend / logout / reboot / shutdown actions with
  the confirmation flow (`pendingAction` two-step) preserved.
- Header shows username (`whoami`) and uptime (`uptime -p`) — keep
  the subprocesses (trivial, and `uptime -p` formatting is the
  contract).
- Commands are user-configurable via the Settings page, general scope
  (profile-independent), defaults identical:
  `loginctl lock-session`, `systemctl suspend`, `swaymsg exit`,
  `systemctl reboot`, `systemctl poweroff`.
- Bar button opens the overlay.

## Stack

- Module crate with manager + button + settings, root component
  `Overlay` (order 200).
- Actions run via `stream/collect` helpers; the configured command
  strings are executed the same way they are today (they are
  user-authored command lines, so `sh -c` is correct here — they are
  configuration, not interpolated device values).

## State

- `power-general.json` (scope `general`), same field names
  (`lockCommand`, `suspendCommand`, `logoutCommand`, `rebootCommand`,
  `shutdownCommand`) and defaults.

## IPC / dshell (unchanged)

- `dshell power toggle|open|close` → `overlay` target, id `power`.
- Sway bind: `mod4+Shift+p` → `dshell power toggle`.

## Keymaps (exact, from `Overlay.qml`)

- `Escape` / `Ctrl+[` close.
- `q` (only **without** Ctrl) close — preserve that modifier guard.
- `Ctrl+n` / `Ctrl+p` next/previous action.
- `Space`/`Return`/`Enter` activate (arm → confirm).

## Verification

- Full keyboard round-trip: open via bind, navigate with `Ctrl+n/p`,
  arm lock, confirm; edit the lock command in settings and re-run;
  cancel paths (`Escape`, `q`) leave no armed action behind.
