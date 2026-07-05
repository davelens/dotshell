# idle-inhibitor — Rust rewrite plan

Ports `modules/idle-inhibitor/` (Manager + Button, ~70 lines QML).
Prevent idle/sleep; today by holding a
`systemd-inhibit --what=idle … sleep infinity` child process.

## Feature parity

- Bar button toggles the inhibitor; icon reflects state (󰈈 variants).
- IPC target `idle`: `enable`, `disable`, `toggle`, `state` — the
  `dshell idle …` rows are unchanged. Feedback strings identical
  ("Idle inhibitor is now enabled"); `state` returns bare
  `true`/`false`; `toggle` delegates to enable/disable (ADR-0002).

## Stack

- Module crate with manager + button (order 210).
- **Replace the subprocess with the logind DBus API via `zbus`**:
  `org.freedesktop.login1.Manager.Inhibit("idle", "dotshell",
  "User requested", "block")` returns an fd; holding it inhibits,
  dropping it releases. Same mechanism systemd-inhibit uses
  internally — identical effect, no `sleep infinity` child to leak or
  reap.

## State

- None persisted (state is the live inhibitor, resets on restart —
  same as today).

## Keymaps

- Button activates via bar focus mode `Space`/`Return`/`Enter` or
  click. No popup.

## Verification

- `dshell idle toggle` twice: feedback strings match current output
  verbatim; `systemd-inhibit --list` shows the hold appearing and
  disappearing; `dshell idle state` prints bare `true`/`false`.
