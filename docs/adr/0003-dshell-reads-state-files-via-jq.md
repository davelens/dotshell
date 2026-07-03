# dshell reads state from files via jq — no IPC read adapter

An architecture review (2026-07) proposed a state-read seam with two
adapters: IPC when the shell is running, file reads otherwise. Inventory
killed the IPC half:

- The QML IPC surface covers only 3 of ~8 reads the CLI needs (profile
  names, active profile, active theme); completion sources (settings
  categories, popup module ids, theme catalogue) and wallpaper state are
  not exposed.
- State files are authoritative immediately — QML calls `saveConfig()` on
  every change — so IPC reads buy no freshness, only latency on every TAB
  completion and a failure mode when the shell is down.
- The boot path (`wallpaper restore` at compositor startup) needs file
  reads regardless.

Decided: all CLI reads go through one `json_get <file> <jq-filter>
[default]` helper on a hard `jq` dependency (sed scrapers and the
hand-rolled bash JSON parser are gone). Mutations and genuinely
shell-dependent queries still go through `ipc()`. The QML IpcHandler read
functions (`profile list/current`, `theme current`) stay for external
`qs ipc call` users but the CLI does not use them.

Do not re-propose an IPC read adapter unless the CLI starts needing state
that exists only in the running shell (not persisted to files).
