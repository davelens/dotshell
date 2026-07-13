# Operations

- `~/.config/dotshell` symlinks to this repo, so edits hit the live instance.
- Arch runs dotshell as the `dotshell.service` systemd user unit:
  - restart: `systemctl --user restart dotshell.service`
  - logs: `journalctl --user -u dotshell.service`
- Void runs it as a turnstile-managed runit user service:
  - restart: `sv restart ~/.config/service/dotshell`
  - status/output: `sv status ~/.config/service/dotshell`; output follows the
    turnstile user service supervisor's logging configuration.
  - the run script asks Sway to create the actual process in the active elogind
    session, then monitors its PID; this same-session bridge is required for
    graphical polkit authentication.
- QML hot-reload usually fires on save but the file watcher can silently stop
  (observed 2026-07). Restart the applicable service when IPC or behavior looks
  stale.
- Verify the live IPC surface with `qs -p ~/.config/dotshell ipc show`.
- Popup/overlay IPC within a few seconds of a restart can race initialization —
  retest before treating a misbehaving toggle as real.
- Bash completion is lazy-loaded per shell session; after changing
  `bin/dshell-completion.bash`, `source` it or open a new terminal.
