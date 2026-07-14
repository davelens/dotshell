[Back to API](./index.md)

# The dshell CLI

Autocompleted command-line companion to the shell: every user-facing
operation goes through `dshell` instead of raw `qs ipc call`. Symlinked into
`$XDG_BIN_HOME` (or `~/.local/bin` when unset) by `setup/init.sh`.

`bin/dshell`

## Command registry

The `COMMANDS` array at the top of `bin/dshell` is the single source of
truth. Dispatch, per-prefix usage text, and bash completion are all
generated views of it — adding a subcommand means adding one row (plus
an IpcHandler function on the QML side when it's a new mutation).

Row format: `"path|handler|args|description"`.

| Field | Meaning |
| --- | --- |
| `path` | words after `dshell`, matched verbatim (`bar focus toggle`) |
| `handler` | `ipc <target> <function> [fixed-args…]` or `fn <local function>` |
| `args` | `<x>` required, `[x]` optional; `:source` suffix names the completion source |
| `description` | one line, shown in usage |

Completion sources: `theme`, `profile`, `category`, `popup` (value
lists), `file` (emits the `__files__` sentinel so the completion adapter
falls back to filename completion). `GROUP_DESCRIPTIONS` supplies the
top-level usage lines.

## Verb grammar (ADR-0002)

- Stateful features: `enable | disable | toggle | state` (idle,
  bar focus).
- Overlays/panels: `toggle | open | close`.
- Named selections: `list | current | set <name>` (theme, profile).
- Facet + verb when a bare verb would mislead: `bar focus toggle`,
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
[default]`; jq is a hard dependency. IPC is for mutations only — the
state files are authoritative (QML saves on every change) and reads must
work with the shell down (`wallpaper restore` runs at compositor
startup, before the shell).

## Completion

`bin/dshell-completion.bash` is a thin adapter: it calls
`dshell --complete <words…>` and hands the result to `compgen`. It is
lazy-loaded per shell session — after changing it, `source` it or open a
new terminal.

## Adding a new subcommand

1. Add the IpcHandler function in the owning QML manager, returning a
   feedback string (or `error: …`).
2. Add one `COMMANDS` row. New command group → also one
   `GROUP_DESCRIPTIONS` row.
3. New argument kind → add a completion source function and a case in
   `complete_words`.
4. Update the command table in `README.md`.
