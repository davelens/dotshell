# Compositor backend seam

**Status:** parked — revisit when support for a third window manager
(e.g. Hyprland, river) is actually wanted.

## Finding (core/module coupling audit, 2026-09)

`core/Compositor.qml` is already the compositor abstraction and its public
interface is sound (`resolvedBackend`, `focusedOutputName`, `focusWindow`,
`applyPosition`, `applyScale`, `setOutputActive`,
`moveFocusedWorkspaceToOutput`, `fetchOutputs`, result signals). Internally
though it is a switchboard: every function branches
`resolvedBackend === "niri" ? … : …` with parallel `Process` objects per
backend, so adding a compositor means editing every function in one large
file. The `workspaces` module already demonstrates the better shape: a
`Loader` picks `I3Backend.qml` / `NiriBackend.qml` behind one interface, and
a new backend is one new file.

A compositor seam in core alone does not make WM support pluggable:
`modules/power` and `modules/wallpaper` shell out to `swaymsg`/`niri`
directly, and `modules/workspaces` ships its own backend pair. Keybindings
live in the dotfiles repo (`config/sway/config.d/50-keybindings`) and stay
out of scope.

## Plan

- Split `core/Compositor.qml` into `core/compositor/SwayBackend.qml` and
  `core/compositor/NiriBackend.qml` behind a `Loader`, keeping the current
  public interface on the `Compositor` singleton (callers don't change).
  Detection stays env-var based; each backend owns its processes and its
  focused-output tracking (Sway via `Quickshell.I3`, Niri via its IPC).
- Route the direct compositor calls in `modules/power` and
  `modules/wallpaper` through `Compositor` helpers so a port doesn't need a
  repo-wide grep for `swaymsg`.
- Point the workspaces module's backend choice at
  `Compositor.resolvedBackend` for auto-detection; its backends stay
  module-owned (workspace listing is a module concern, not core).
- Adding a WM then means: one core backend file, one workspaces backend
  file, plus setup/keybinding work outside this repo.
- Do **not** make backends manifest-discovered like modules: compositors are
  not per-user removable features, and a WM contributor edits the repo
  anyway (see the module-pluggability constraint's "seam only when two real
  implementations exist" rule — the third implementation is the trigger
  here).

## Cost / why parked

Pure restructuring with zero behavior change while only Sway and Niri
exist; the switchboard is ugly but correct, and the interface extraction
(focused-output unification, ScreenManager decoupled from `Quickshell.I3`)
already landed. Worth doing as the first step of any third-WM effort.
