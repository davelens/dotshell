# Operations

- Shell runs as `quickshell.service` (user unit); `~/.config/dotshell`
  symlinks to this repo, so edits hit the live instance.
- QML hot-reload usually fires on save but the file watcher can silently
  stop (observed 2026-07: `touch` no longer triggered reloads). When IPC
  surface or behavior looks stale: `systemctl --user restart
  quickshell.service`.
- Verify the live IPC surface with `qs -p ~/.config/dotshell ipc show`;
  errors via `journalctl --user -u quickshell.service`.
- Popup/overlay IPC within a few seconds of a restart can race
  initialization — retest before treating a misbehaving toggle as real.
- Bash completion is lazy-loaded per shell session; after changing
  `bin/dshell-completion.bash`, `source` it or open a new terminal.
