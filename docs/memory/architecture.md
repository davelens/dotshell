# Architecture

## Hard constraint: modules are pluggable and self-contained

Anything under `modules/` can be added or removed without touching core.
Core (`core/`, `shell.qml`, `statusbar/`, `settings/`) must not hardcode
module ids, labels, or state-file names. Sanctioned mechanisms:

- **Manifests** — modules self-describe in `module.json`; core queries
  through `ModuleRegistry` (`hasPopup`, `getBarComponents`, …).
- **Runtime registration** — managers announce capabilities at startup
  (e.g. `OverlayManager.register(id, label)`); the registrations double
  as the known-id list for IPC validation.

Soft exceptions exist by design (statusbar default layout, rename map,
settings category order) — mitigated and documented in `docs/plans/`.

## State ownership

Persisted state via `ModuleConfig { moduleId: … }` — the key names the
*owner*, not the nearest module. Core-owned state uses core keys
(`screens.json` for ScreenManager's primary display; `statusbar.json`).
Profile-scoped by default; `scope: "general"` for profile-independent.

## QML process conventions (ADR-0001)

No custom Command wrapper. One-shot output capture uses `StdioCollector`;
`SplitParser` only for genuine line/event streaming; user- or
device-provided values never concatenated into `sh -c` strings — use argv
elements, `Process.environment`, or `"$@"`. `FileView.setText()` writes
atomically.

## dshell CLI invariants

- `COMMANDS` registry in `bin/dshell` is the single source of truth:
  dispatch, usage, completion (`dshell --complete`) are generated views.
- Verb grammar + `error:`-prefix feedback convention: ADR-0002.
- All state reads via `json_get` on jq (hard dep); IPC for mutations
  only: ADR-0003.
- No compat aliases on CLI/IPC renames; keybindings (dotfiles repo,
  `config/sway/config.d/50-keybindings`) update in the same change.
