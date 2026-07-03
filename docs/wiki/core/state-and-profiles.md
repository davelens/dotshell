[Back to core](./index.md)

# State and profiles

All persisted state lives under `$XDG_DATA_HOME/dotshell/`, most of it
scoped to a named profile so complete shell configurations can be
switched at runtime.

`core/DataManager.qml` · `core/ModuleConfig.qml` · `core/GeneralSettings.qml`

## Layout

| Path | Content |
| --- | --- |
| `general.json` | theme, profiles list, active profile, settings category order |
| `<moduleId>-general.json` | profile-independent module state (`scope: "general"`) |
| `<profileDir>/<moduleId>.json` | profile-scoped module state (default) |
| `themes/` | user theme overrides |

## Readiness (two stages)

DataManager bootstraps in two gated stages: `dataDirReady` (data +
themes dirs exist) → GeneralSettings loads `general.json` and calls
`setActiveProfile(dir)` → profile dir created → `ready`. Profile-scoped
`ModuleConfig`s wait on `ready`; general-scoped on `dataDirReady`.
Switching profiles cycles `ready` false → true, which reloads every
profile-scoped config.

## ModuleConfig

Single point of truth for module persistence, keyed by `moduleId` —
the key names the state file's *owner* (core state uses core keys, e.g.
`screens`). Two modes:

- **Adapter mode**: assign a `JsonAdapter`; file is loaded, watched for
  external changes, written back on property change, and created from
  the adapter defaults when missing — QML defaults are the only
  defaults.
- **Manual mode**: listen to `loaded(text)`, persist with
  `save(object)`; missing file emits `loaded("")`.

## Profile lifecycle (`GeneralSettings`)

- **Create**: `createProfile(name)` sanitizes the name into a dir,
  copies the current profile's `*.json`, auto-switches to it.
- **Switch**: `switchProfile(dir)` persists, then
  `DataManager.setActiveProfile` cycles readiness.
- **Delete**: refused for the first (default) profile and the active
  profile; otherwise removes the entry and `rm -rf`s the dir.

IPC: `profile list/current/set` and `theme current/set` live here
(`dshell profile …`, `dshell theme …`).
