# Manifest-driven statusbar defaults

**Status:** parked — revisit if dotshell is prepared for public consumption.

## Finding (architecture review, 2026-07, F2)

The default bar layout in `statusbar/Manager.qml` (the `left`/`center`/
`right` arrays in the config defaults) hardcodes all 18 module ids,
including personal modules (`active-collab`, `ai-agents-monitor`). Core
naming pluggable modules violates the module self-containment rule,
though softly:

- `filterValidItems()` drops ids whose module has no bar component, so a
  removed module cannot break the bar.
- `ensureAllModulesPresent()` prepends unknown new modules (disabled) to
  the right section, so a dropped-in module appears without core edits.

The mechanism is sound; only the *defaults* carry module knowledge.

## Plan

Move layout defaults into each module's `module.json`:

```json
"bar": { "section": "right", "marginRight": 10, "defaultEnabled": true }
```

- `ModuleRegistry` exposes the fields like it does `components`/`order`.
- `statusbar/Manager.qml` builds its default layout from the manifests
  (sorted by the existing `order` field within each section) instead of
  the hardcoded arrays; the arrays are deleted.
- `filterValidItems` / `ensureAllModulesPresent` stay — user state still
  overrides defaults.

## Cost / why parked

Manifest schema creep for a purely cosmetic problem: on a personal setup
the hardcoded defaults are correct by definition, and the existing
filter/ensure mechanics already keep the bar valid when modules come and
go. Worth doing only when third parties are expected to add/remove
modules without touching core.
