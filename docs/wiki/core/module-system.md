[Back to core](./index.md)

# Module system

Modules are self-contained feature directories under `modules/`,
discovered at startup from their `module.json` manifests. Core never
names modules (see `../../memory/architecture.md`); everything flows
through `ModuleRegistry`.

`core/ModuleRegistry.qml`

## Discovery

One `sh` process globs `modules/*/module.json` plus the manifests of
`coreManifestDirs` (currently `["statusbar"]` — statusbar ships a
manifest so it gets a settings page, but is not a removable module).
Parsed modules are sorted by `order` (default 100) and exposed on
`ModuleRegistry.modules`; `ready` flips true once.

After discovery, executables in `modules/*/bin/` are symlinked into
`~/.local/bin` (dangling symlinks pointing into `modules/` are pruned
first, so removing a module cleans up its binaries).

## Manifest schema (`module.json`)

| Field | Meaning |
| --- | --- |
| `id` | stable module id (state file name, IPC/CLI references) |
| `name` | display name (settings sidebar, logs) |
| `icon` | nerd-font glyph for the settings sidebar |
| `order` | sort key for settings categories and unlisted ordering |
| `keywords` | settings search terms |
| `components.manager` | singleton with state/logic (also holds IPC handlers) |
| `components.button` / `components.segment` | bar component (button = clickable, segment = passive) |
| `components.popup` | bar-anchored popup window |
| `components.settings` | settings panel page |
| `rootComponents` | files instantiated once at shell root (panels, popup windows) |
| `skipBarFocus` | exclude from bar keyboard navigation |
| `requiresHostWindow` | inject the containing bar window into a bar component as `hostWindow` |

## Loading (`shell.qml`)

When `ModuleRegistry.ready` fires, `shell.qml` instantiates every
module's popup component (injecting `moduleId`) and every
`rootComponents` entry — guarded by `_componentsLoaded` so rediscovery
can't double-instantiate. Bar components load per enabled statusbar
item via `Loader.setSource` with *relative* paths
(`getBarComponentRelPath`) — `file://` URLs would give modules an
isolated singleton set.

## Adding a module

Create `modules/<dir>/module.json` with an `id` and the components that
apply. Discovery, bar placement (auto-prepended disabled to the right
section), settings page, popup wiring, and bin symlinking all follow
from the manifest — no core edits.
