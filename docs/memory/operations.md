# Operations

- `~/.config/dotshell` symlinks to this repo, so edits hit the live instance.
- Arch runs the shell as the `quickshell.service` systemd user unit:
  - restart: `systemctl --user restart quickshell.service`
  - logs: `journalctl --user -u quickshell.service`
- Void runs it as a turnstile-managed runit user service:
  - restart: `sv restart ~/.config/service/quickshell`
  - status/output: `sv status ~/.config/service/quickshell`; output follows the
    turnstile user service supervisor's logging configuration.
- QML hot-reload usually fires on save but the file watcher can silently stop
  (observed 2026-07). Restart the applicable service when IPC or behavior looks
  stale.
- Verify the live IPC surface with `qs -p ~/.config/dotshell ipc show`.
- Popup/overlay IPC within a few seconds of a restart can race initialization —
  retest before treating a misbehaving toggle as real.
- Bash completion is lazy-loaded per shell session; after changing
  `bin/dshell-completion.bash`, `source` it or open a new terminal.
