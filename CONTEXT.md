# Domain language

Terms used consistently across code and docs. Keep this list short and exact.

- **Module** — a drop-in folder under `modules/` with a `module.json` manifest.
  Modules must be self-contained: dropping the folder in (plus its manifest)
  is all that's required to register bar components, popups, and settings.
- **ModuleConfig** — the single persistence mechanism for module state
  (`core/ModuleConfig.qml`). Two modes: *adapter mode* (a `JsonAdapter`
  declares typed properties; their QML defaults are the only defaults) and
  *manual mode* (`loaded(text)` + atomic `save(object)` for dynamic
  structures like the statusbar layout).
- **Scope** — where module state lives. `profile`: per-profile, under the
  active profile directory, gated on `DataManager.ready`. `general`:
  profile-independent, at the data dir root as `<id>-general.json`, gated on
  `DataManager.dataDirReady`.
- **Defaults** — declared once, in QML, on the adapter (or as a
  `defaultConfig` object for manual-mode consumers). There are no
  `defaults.json` files and no defaults copy step; a missing state file is
  recreated from the QML defaults.
- **Profile** — a named directory of profile-scoped state files under the
  data dir, managed by `GeneralSettings`. The first-run profile is named
  `defaults` (directory name), displayed as "Default".
