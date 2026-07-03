[Back to core](./index.md)

# Statusbar

A 32px top bar on the primary screen only (`ScreenManager.primaryScreen`
drives a single-element `Variants` in `shell.qml`). Three sections —
left, center, right — each an ordered list of module items.

`statusbar/Manager.qml` · `shell.qml`

## Configuration (`statusbar.json`, profile-scoped)

Per item: `{ id, enabled, marginLeft, marginRight }`. Bar-wide:
`barMargins`, `sectionSpacing`, `popupStem` (stem connector between a
popup and its bar button; see
[overlay-and-popup-ipc](../api/overlay-and-popup-ipc.md)).

Config load is deferred until `ModuleRegistry.ready`, then
self-healing, persisting back when anything changed:

1. `_migrateId` rewrites renamed module ids (map in core for now — plan:
   `docs/plans/module-rename-migrations-in-manifest.md`).
2. `filterValidItems` drops items whose module has no bar component.
3. `mergeNewModules` prepends unseen modules (disabled) to the right
   section.

Empty/missing file → built-in `defaultConfig` (hardcoded layout — plan:
`docs/plans/manifest-driven-statusbar-defaults.md`).

## Bar focus mode

Keyboard navigation over enabled bar items: one unified index spans
left → center → right; `resolveSection(idx)` maps back to a section and
repeater item. Items are skipped when invisible or when their manifest
sets `skipBarFocus`. Activation: popup modules toggle their popup,
buttons fire `clicked()`, segments with `activate()` run it, anything
else dismisses focus mode. While active the bar takes exclusive
keyboard focus (`WlrKeyboardFocus.Exclusive`).

Controlled via `dshell bar focus toggle|enable|disable|state`
(IpcHandler in `shell.qml`).
