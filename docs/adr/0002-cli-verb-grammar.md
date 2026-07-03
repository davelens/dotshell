# dshell verb grammar and IPC feedback convention

An architecture review (2026-07) found six dialects for the same operations
across `dshell` subcommands (`bar focus`, `screen-recording files`,
`wallpaper browse` all meaning "toggle a panel"; `profile enable` vs
`theme set`; silent mutations). Decided:

- **Three verb families.** Stateful features: `enable | disable | toggle |
  state`. Overlays/panels: `toggle | open | close`. Named selections:
  `list | current | set <name>`.
- **Facet + verb** when a module has more than one facet or the bare verb
  would mislead: `bar focus toggle`, `screen-recording files toggle`,
  `wallpaper browser toggle`. Single-panel modules stay two-level
  (`notifications toggle`). Flat `screen-recording toggle` was rejected:
  it collides with a future start/stop recording verb.
- **Every mutation returns a feedback string** from the QML IpcHandler
  ("Idle inhibitor is now enabled"); `toggle()` delegates to `enable()` /
  `disable()` so the message is written once. State queries return bare
  values (`true`/`false`) for scripting.
- **Error convention:** QML returns strings prefixed `error:`; the `ipc()`
  helper in `bin/dshell` routes them to stderr and exits non-zero
  (`qs ipc call` itself always exits 0). No CLI-side re-validation of
  names the shell already knows.
- **No compat aliases.** Old verbs (`profile enable`, `wallpaper browse`,
  bare `bar focus`) are hard-removed; keybindings updated in the same
  change.
