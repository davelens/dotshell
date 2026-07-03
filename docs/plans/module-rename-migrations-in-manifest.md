# Module rename migrations via manifest

**Status:** parked — do this when the next module rename happens.

## Finding (architecture review, 2026-07, F3)

`statusbar/Manager.qml` carries a rename-migration map in core:

```qml
readonly property var _renamedModules: ({
  "opencode": "ai-agents-monitor"
})
```

`_migrateId()` rewrites old ids found in persisted statusbar config to
their new names. This is module knowledge in core: the fact that
`ai-agents-monitor` was once called `opencode` belongs to that module.

## Plan

- `module.json` gains an optional field:

```json
"formerlyKnownAs": ["opencode"]
```

- `ModuleRegistry` builds the old→new map from manifests and exposes a
  lookup (e.g. `migrateId(id)`), replacing `_renamedModules` /
  `_migrateId` in `statusbar/Manager.qml`.
- Any other persisted-id consumer (settings category order, future state)
  can use the same lookup.

## Cost / why parked

One entry exists today and it works. The manifest field plus registry
lookup is ~20 lines; do it as part of the next rename instead of as a
standalone change.
