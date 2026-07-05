# Rust rewrite — plan index

Goal: same shell, same features, same keymaps, ~10-15x less memory.
Measured baseline: 316MB RSS idle (~64MB Mesa/LLVM GPU driver, ~107MB
QML heap/scene graph, ~30MB Qt libs), escalating to 400-500MB with
panels open. Target: 20-40MB idle, transient bumps only while a panel
is open, fully reclaimed on close.

Strategy that gets there: CPU rendering only (no GPU pipeline → no
Mesa/LLVM), no QML engine, surfaces created on demand and dropped on
close.

## Plans

- [Core](core.md) — daemon, rendering, widget toolkit, module system,
  state/profiles, IPC, statusbar, settings panel, theming, keymap
  engine, `dshell` changes, port order.

Per module (one plan each):

- [active-collab](modules/active-collab.md)
- [ai-agents-monitor](modules/ai-agents-monitor.md)
- [battery](modules/battery.md)
- [bluetooth](modules/bluetooth.md)
- [brightness](modules/brightness.md)
- [clock](modules/clock.md)
- [display](modules/display.md)
- [idle-inhibitor](modules/idle-inhibitor.md)
- [media](modules/media.md)
- [notifications](modules/notifications.md)
- [power](modules/power.md)
- [recording](modules/recording.md)
- [system-load](modules/system-load.md)
- [updates](modules/updates.md)
- [volume](modules/volume.md)
- [wallpaper](modules/wallpaper.md)
- [wireless](modules/wireless.md)
- [workspaces](modules/workspaces.md)

## Non-negotiables (apply to every plan)

1. **Pluggable modules stay the key feature.** Core never names module
   ids (`docs/memory/architecture.md`). See core plan §Module system
   for how this survives compile-time linking.
2. **Every keymap keeps working exactly as today** — the seven sway
   binds that call `dshell`, the pactl/brightnessctl media keys the
   shell must reflect, and every in-shell key (bar focus mode, popup,
   panel, and widget-level navigation). Each plan enumerates its keys;
   the core plan owns the keymap engine.
3. **State files, profiles, and themes are format-compatible.** Same
   `$XDG_DATA_HOME/dotshell/` layout, same JSON schemas, same theme
   files. A user switches shells without migrating anything, and
   `dshell`'s `json_get` reads keep working unchanged (ADR-0003).
4. **`dshell` keeps its exact CLI surface.** Only the IPC transport
   inside `ipc()` changes (core plan §dshell).
