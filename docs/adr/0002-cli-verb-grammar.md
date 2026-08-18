# dshell verb grammar and IPC feedback convention

An architecture review (2026-07) found six dialects for the same operations
across `dshell` subcommands. Historical examples included bare `bar focus`,
`wallpaper browse`, `profile enable`, and silent mutations. Decided:

- **Three verb families.** Stateful features: `enable | disable | toggle |
  state`. Overlays/panels: `toggle | open | close`. Named selections:
  `list | current | set <name>`.
- **Facet + verb** when a module has more than one facet or the bare verb
  would mislead: `status-bar focus toggle`, `screen-recording files toggle`,
  `wallpaper browser toggle`. Single-panel modules stay two-level
  (`notifications toggle`). Flat `screen-recording toggle` is reserved for
  possible recording control rather than the file browser.
- **Every mutation returns a feedback string** from the QML IpcHandler
  ("Idle inhibitor is now enabled"); `toggle()` delegates to `enable()` /
  `disable()` so the message is written once. State queries return bare
  values (`true`/`false`) for scripting.
- **Error convention:** QML returns strings prefixed `error:`; the `ipc()`
  helper in `bin/dshell` routes them to stderr and exits non-zero
  (`qs ipc call` itself always exits 0). No CLI-side re-validation of
  names the shell already knows.
- **Module-owned command groups.** Executable names use module ids:
  `ai-agents-monitor`, `idle-inhibitor`, `screen-recording`, and `wireless`.
  Popup modules expose their own `toggle` command (`bluetooth`, `brightness`,
  `display`, `system-updates`, `volume`, `wireless`) instead of a public generic
  popup command. Internal IPC target names remain independent of this vocabulary.
- **No compat aliases.** Historical verbs and command groups (`profile
  enable`, `wallpaper browse`, bare `bar focus`, `bar`, `agents`, `idle`,
  `network`, `popup toggle <id>`, and `recording`) were hard-removed; keybindings
  were updated in the same changes.
