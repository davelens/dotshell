[Back to API](./index.md)

# The dshell CLI

Autocompleted command-line companion to the shell: every user-facing
operation goes through `dshell` instead of raw `qs ipc call`. Symlinked into
`$XDG_BIN_HOME` (or `~/.local/bin` when unset) by `setup/init.sh`.

`bin/dshell`

## Distributed command registry

`bin/dshell` owns the core `COMMANDS` and `GROUP_DESCRIPTIONS`
registrations, dispatch, per-prefix usage, completion, and the
`dshell_register_group` / `dshell_register_command` helper API. On every
invocation, including `dshell --complete`, it discovers and sources
`$CONFIG_DIR/modules/<module-id>/dshell/init.sh`.

An extension file is side-effect-free: it only calls the registration helpers
and, when needed, defines local CLI functions. Its paths are automatically
prefixed with the module id inferred from its directory. The combined core and
installed-module registrations are the source of truth, so removing a module
removes its CLI. There is no CLI declaration in `module.json`, no setup change,
and no compatibility aliases.

Row format: `"path|handler|args|description"` internally, or the corresponding
four arguments to `dshell_register_command` in an extension.

| Field | Meaning |
| --- | --- |
| `path` | words after `dshell`, matched verbatim (`status-bar focus toggle`) |
| `handler` | `ipc <target> <function> [fixed-args…]`, `listen <target> <signal>`, or `fn <local function>` |
| `args` | `<x>` required, `[x]` optional; `:source` suffix names the completion source |
| `description` | one line, shown in usage |

Completion sources: `theme`, `profile`, and `category` (value lists), plus
`file` (emits the `__files__` sentinel so the completion adapter falls back to
filename completion). `GROUP_DESCRIPTIONS` supplies the top-level usage lines.

## Verb grammar (ADR-0002)

- Stateful features: `enable | disable | toggle | state` (idle inhibitor,
  status bar focus).
- Overlays/panels: `toggle | open | close`.
- Named selections: `list | current | set <name>` (theme, profile).
- Facet + verb when a bare verb would mislead: `status-bar focus toggle`,
  `screen-recording files toggle`, `wallpaper browser toggle`.

## Feedback and errors

Every mutation returns a feedback string from its QML IpcHandler
("Idle inhibitor is now enabled"); `toggle()` implementations delegate to
`enable()`/`disable()` so messages are written once. `qs ipc call`
always exits 0, so the `ipc()` helper supplies error semantics: a
returned string prefixed `error:` goes to stderr and exits 1. State
queries return bare values (`true`/`false`) for scripting.

## State reads (ADR-0003)

All reads of dotshell JSON state go through `json_get <file> <jq-filter>
[default]`; jq is a hard dependency. IPC is for mutations and genuinely shell-dependent runtime queries only —
the state files are authoritative for persisted reads and must work with the
shell down (`wallpaper restore` runs at compositor startup, before the shell).
`ai-agents-monitor current` and `ai-agents-monitor listen` cross the internal
`agents` IPC target because active agent snapshots exist only in the running
shell; both use `--any-display` so they also work in non-graphical SSH sessions.

## Completion

`bin/dshell-completion.bash` is a thin adapter: it calls
`dshell --complete <words…>` and hands the result to `compgen`. It is
lazy-loaded per shell session — after changing it, `source` it or open a
new terminal.

## Adding a new subcommand

For core groups (`status-bar`, `profile`, `settings`, `theme`), add registrations in
`bin/dshell`. For a module group, add or update the module's
`dshell/init.sh`; do not add it to core, the manifest, or setup.

1. Add the IpcHandler function or signal in the owning QML manager, returning
   a feedback string (or `error: …`) for functions, or define a local CLI
   function without invoking it while the extension is sourced.
2. Register the command and, for a new module extension, its group description.
3. New argument kind → add a completion source function and a case in
   `complete_words`.
4. Update the command table in `README.md`.
