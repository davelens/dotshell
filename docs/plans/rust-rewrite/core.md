# Core plan — Rust rewrite

Replaces `shell.qml`, `core/`, `statusbar/`, `settings/`, and the
Quickshell runtime with a single Rust daemon. Optimized for
maintainability and readability: small crates with one job each, names
that mirror the QML files they replace (grep `OverlayManager` in either
codebase and land in the right place), and boring, widely-used
dependencies.

## Process model

One long-lived daemon (`dotshell`). Panels, popups, and the settings
window are created on demand and torn down completely on close — with
CPU rendering there is no scene graph or GPU context to leak, so the
single-process model stays within budget while keeping shared state
trivial (no cross-process sync for settings mutations). If real-world
numbers disappoint, the escalation path is moving panels into
short-lived child processes behind the same `View` seam; nothing in
this plan blocks that.

The same binary doubles as IPC client (`dotshell ipc call …`), the way
`swaymsg` is both. No separate client tool to version-skew against.

## Software stack

| Concern | Choice | Why |
| --- | --- | --- |
| Language / layout | Rust, cargo workspace | one crate per concern, modules are crates |
| Wayland client | `smithay-client-toolkit` (`wayland-client`) | reference client stack; layer-shell, seats, outputs, shm pools |
| Surfaces | `zwlr_layer_shell_v1` | bar, popups, panels, overlays — same namespaces as today |
| Event loop | `calloop` | sctk-native; timers, channels, fds, subprocesses in one single-threaded loop |
| Async islands | `tokio` on one sidecar thread | zbus, HTTP, slow subprocess collection; results funnel back via `calloop::channel` |
| Rendering | `tiny-skia` into wl_shm buffers | pure CPU raster — this is the memory win; no wgpu, no GL, no Mesa |
| Text | `cosmic-text` (+ `fontdb`) | shaping, font fallback (Hack Nerd Font glyphs), editable text fields |
| Layout | `taffy` | flexbox; replaces QML anchors/Row/Column |
| Keyboard | `xkbcommon` via sctk seat handling | keysym-level keymaps, identical to Qt key handling semantics |
| DBus | `zbus` | pure-Rust async; notification server + UPower/Mpris/BlueZ/logind clients |
| State | `serde_json` + atomic write (tmp + rename) + `notify` file watching | same files, same schemas, same external-edit reload behavior |
| Subprocesses | `tokio::process` behind two helpers | see §Process conventions |
| Images | `image` crate | wallpaper thumbnails, notification icons |
| Compositor IPC | `swayipc-async`, niri socket (JSON) | see §Compositor |

Explicitly rejected: `iced`/anything `wgpu`-based (reimports the 64MB
Mesa/LLVM cost we are here to kill), GTK (60-100MB baseline), dynamic
`.so` plugins (no stable Rust ABI).

## Workspace layout

```
Cargo.toml            # workspace
crates/
  dotshell/           # bin: daemon + ipc client subcommand
  ds-core/            # AppState, DataManager, GeneralSettings, Theme, Time,
                      # ModuleConfig, OverlayManager, PopupManager,
                      # ScreenManager, Compositor  (one .rs per QML peer)
  ds-ui/              # widget toolkit (see §Widget toolkit)
  ds-wayland/         # sctk plumbing: outputs, seats, layer surfaces, shm
  ds-modules-all/     # GENERATED aggregation crate (see §Module system)
modules/
  <id>/               # one crate per module + its module.json + bin/
bin/dshell            # stays bash (see §dshell)
```

## Widget toolkit (`ds-ui`)

The riskiest piece and the maintainability crux, so it stays minimal
and mirrors the existing component set 1:1 — same names, same
behavior, nothing speculative:

- Scaffolds: `PopupBase`, `PanelBase`, `TooltipBase`, `DialogOverlay`,
  `ModulePopup`, `SettingsPage`, `BarButton`, `BarSection`.
- Focusable widgets: `FocusButton`, `FocusIconButton`, `FocusLink`,
  `FocusListItem`, `FocusSlider`, `FocusTextInput`, `PasswordInput`,
  `Dropdown`, `SwitchToggle`, `TimePicker`, `KeyboardTag`.
- Text styles: `TitleText`, `BodyText`, `HelpText`, `AnnotationText`,
  `SuccessText` (font/size/color presets from Theme).

Retained tree, taffy for layout, damage-tracked redraw (repaint only
dirty widgets into the shm buffer). Focus model is a linear ring per
surface, exactly like the QML `Focus*` chain. Every widget's built-in
keys are part of the keymap contract:

- `FocusSlider`: `h`/`Left` decrease, `l`/`Right` increase.
- `Dropdown`: `Space`/`Return`/`Enter` open/select, `j`/`Down` next,
  `k`/`Up` previous, `Escape` close.
- `SwitchToggle`, buttons, list items: `Space`/`Return`/`Enter`
  activate.
- `DialogOverlay`: `Escape` / `Ctrl+[` close.
- `PopupBase`: `Escape`/`q`/`Ctrl+[` close, `Ctrl+n` next focus,
  `Ctrl+p` previous focus.

## Keymap engine

One `Keymap` type: ordered list of `(modifiers, keysym) → Action`,
resolved innermost-surface-first (widget → scaffold → surface), which
is exactly Qt's event propagation today. Every surface declares its
map as data, so the full binding set is greppable in one place per
surface and testable without a compositor.

External bindings are untouched by design (they live in the dotfiles
repo and call `dshell` or system tools):

| Bind | Command | What must keep working |
| --- | --- | --- |
| `$mod+Shift+s` | `dshell settings toggle` | settings overlay |
| `$mod+Shift+n` | `dshell notifications toggle` | notification panel |
| `$mod+Shift+u` | `dshell popup toggle updates` | updates popup (stemless when no button) |
| `$mod+Shift+b` | `dshell bar focus toggle` | bar focus mode |
| `mod4+Shift+p` | `dshell power toggle` | power overlay |
| `mod4+Shift+s` | `dshell screen-recording files toggle` | recording panel |
| `mod4+Shift+w` | `dshell wallpaper browser toggle` | wallpaper panel |
| `XF86Audio*` ×4 | `pactl` | shell reflects sink/source changes (volume module subscribes) |
| `XF86MonBrightness*` ×2 | `brightnessctl` | shell reflects backlight changes (brightness module) |

Bar focus mode (owned by the bar surface, ports `shell.qml`):
`Escape`/`q`/`Ctrl+[` dismiss, `Space`/`Return`/`Enter` activate item
(popup toggle / button click / segment activate / dismiss), `l` next
item, `h` previous item. Unified index across left→center→right
sections; invisible and `skipBarFocus` items skipped; exclusive
keyboard focus while active (`zwlr_layer_surface` keyboard
interactivity `exclusive`).

## Module system (the key feature)

Hard constraint preserved: core never names module ids. Mechanisms:

1. **Manifests stay.** `modules/<id>/module.json` is still the
   self-description: id, name, icon, order, keywords, which components
   exist, `rootComponents`, `skipBarFocus`. `ModuleRegistry` (in
   `ds-core`) parses them at startup exactly as today and remains the
   only way core queries module capabilities (`has_popup`,
   `bar_component`, …). Settings sidebar, bar merge, and popup wiring
   all flow from the manifest.
2. **Runtime registration stays.** `OverlayManager::register(id,
   label)` at module init; registrations are the known-id list for
   `overlay` IPC validation and the labels for feedback strings.
   `PopupManager::register_button` for stem/anchor resolution.
3. **The Rust trait** each module crate implements:

   ```rust
   pub trait Module {
       fn id(&self) -> &'static str;                       // must equal module.json id
       fn init(&mut self, ctx: &mut ModuleCtx);            // subscriptions, watchers, registrations
       fn bar_component(&self) -> Option<BarComponent>;    // Button (clickable) | Segment (passive)
       fn popup(&self) -> Option<ViewFactory>;
       fn settings_page(&self) -> Option<ViewFactory>;
       fn root_components(&self) -> Vec<ViewFactory>;      // panels, toast windows
       fn ipc(&mut self, function: &str, args: &[String]) -> IpcReply; // module-owned verbs
   }
   ```

4. **Registration without core edits.** Rust links at compile time, so
   "drop a folder in" becomes "drop a folder in and run one command":
   `cargo xtask sync-modules` globs `modules/*/Cargo.toml` and
   regenerates `ds-modules-all` (its `Cargo.toml` dependency list and
   a `registry()` function returning `Vec<Box<dyn Module>>`). That
   crate is 100% generated and never hand-edited; core source still
   contains zero module names. Removing a module = delete folder,
   re-run sync. The xtask also runs automatically from `setup/init.sh`
   and is checked in CI so a stale registry cannot ship.
5. **Exec modules (bonus, out-of-tree).** A manifest-only module type
   (`components.exec`: command, interval, click command) rendered by a
   generic segment — recompile-free extension point for scripts,
   waybar-custom-module style. Not used by any bundled module.

`modules/*/bin/` symlinking into `~/.local/bin` (with dangling-link
pruning) ports as-is into `ModuleRegistry` startup.

## State, profiles, theming

- `DataManager` / `GeneralSettings` / `ModuleConfig` port 1:1,
  including the two-stage readiness gates (`data_dir_ready` →
  `ready`), profile create/copy/switch/delete rules, and both
  ModuleConfig modes. Adapter mode becomes a
  `#[derive(Serialize, Deserialize)]` struct with `#[serde(default)]`
  — Rust defaults are the only defaults, missing file recreated from
  them, file watched via `notify` for external edits, saved on change
  (atomic tmp+rename). Manual mode keeps `loaded`/`save` for dynamic
  shapes (statusbar layout).
- File layout and schemas byte-compatible: `general.json`,
  `<profile>/<moduleId>.json`, `<moduleId>-general.json`, `themes/`,
  `screens.json`, `statusbar.json`. `dshell json_get` and existing
  user profiles keep working with zero migration.
- `Theme`: same theme JSON schema, bundled + user override resolution,
  `highlightText` equivalent for settings search, hot reload when
  `general.json` changes (that is how `dshell theme set` — a local fn
  writing the file — takes effect today). `bin/generate-gtk-css`
  stays bash, untouched.

## Statusbar (core-owned, has a manifest for its settings page)

32px top bar, primary screen only, three ordered sections. Ports
`statusbar/Manager.qml` self-healing config load verbatim: deferred
until registry ready, `_migrateId` rename map, `filterValidItems`,
`mergeNewModules` (unseen modules prepended disabled to right
section), persist-back-if-changed, hardcoded `defaultConfig` (the two
existing plans about manifest-driven defaults and rename migrations
apply on top of this one). Per-item margins, `barMargins`,
`sectionSpacing`, `popupStem` all preserved, plus the statusbar
Settings page.

Popup anchoring ports `PopupManager` exactly: registered bar button →
anchored to button's right edge with stem eligibility; no button →
primary screen right edge minus 20px, stemless, square corner, larger
offset.

## Overlays and IPC surface

`OverlayManager`: at most one overlay open; opening closes active
popup and other overlays; `open(id, context)` payloads; `opened(id)`
re-fire semantics; single id-addressed IPC target with
`error: unknown overlay '<id>'` validation. Registered ids come from
modules (`notifications`, `power`, `recording`, `wallpaper`) and core
(`settings`).

Transport: unix socket `$XDG_RUNTIME_DIR/dotshell/ipc.sock`,
JSON-lines request `{target, function, args}` → reply string. Targets
identical to today: `overlay`, `popup`, `bar`, `idle`,
`notifications`, `wallpaper`, `settings`, `theme`, `profile`. Reply
strings keep the feedback conventions: human sentence per mutation,
bare values for `state` queries, `error:` prefix for failures.
`toggle()` keeps delegating to `enable()`/`disable()` so messages are
written once (ADR-0002).

## Settings panel (core)

Full-screen `PanelBase` overlay. Sidebar = registry manifests (icon,
name, order, keywords) + persisted category order; content = module
`settings_page()`. Search with `Ctrl+f`, highlighting via Theme.
Keymaps preserved from `settings/Panel.qml`: `Escape`/`q`/`Ctrl+[`
close, `Ctrl+h`/`Ctrl+l` sidebar↔content, `Ctrl+n`/`Ctrl+p`
next/previous, `Space`/`Return`/`Enter` activate, plus
`NewProfileDialog` / `SwitchProfileDialog` as `DialogOverlay`s.
`settings showCategory <id>` IPC preserved (used by display module's
"configure" jump).

## Compositor (`ds-core::compositor`)

Trait with `Sway` (via `swayipc-async`; also covers i3 semantics) and
`Niri` (JSON over `NIRI_SOCKET`) implementations. Detection identical:
`SWAYSOCK`/`I3SOCK` → sway, `NIRI_SOCKET` → niri, fallback sway with
`detected = false` and every helper no-oping with a warning. Same
helper set: `set_transform`, `focus_window`, `apply_position`,
`fetch_outputs` (async, event-style results). `ScreenManager` ports
as-is: `screens.json`, stable id `model:serialNumber`, first-screen
fallback, drives bar/settings/popup-fallback placement.

## Process conventions (ADR-0001 ports to Rust)

Two helpers in `ds-core`, nothing else spawns directly:
`collect_output(argv) -> Output` (StdioCollector equivalent) and
`stream_lines(argv) -> LineStream` (SplitParser equivalent, for
genuine event streams only). Argv arrays always; user- or
device-provided values never interpolated into `sh -c` strings.

## dshell

`bin/dshell` stays bash and keeps its exact `COMMANDS` registry,
grammar, completion, and `json_get` state reads (ADR-0003 —
reads must work with the shell down). Changes:

1. `ipc()` helper: `qs -p "$CONFIG_DIR" ipc call "$@"` →
   `dotshell ipc call "$@"`. The client exits non-zero on `error:`
   replies itself, but `ipc()` keeps its stderr/exit handling so
   behavior is identical either way.
2. `settings/Panel.qml`'s internal `qs ipc call settings showCategory
   display` becomes an in-process call (no subprocess at all).
3. No row, verb, or completion-source changes. `wallpaper
   set/restore`, `theme *`, `profile list/current` stay local fns on
   `json_get`.
4. `setup/init.sh` and the systemd user service switch the started
   binary from `quickshell -p …` to `dotshell`; symlinks and the rest
   of setup unchanged.

## Port order

Each step lands runnable; quickshell stays the daily driver until
parity per surface.

1. Skeleton: `ds-wayland` + bar window rendering static text on the
   primary screen; IPC socket + `dotshell ipc call`; `dshell` ipc()
   switch behind an env flag for side-by-side testing.
2. `ds-core`: state/profiles/theme/registry/compositor; clock +
   workspaces + system-load segments (proves render, timers, sway/niri
   IPC).
3. `ds-ui` focus widgets + PopupBase + bar focus mode; volume +
   brightness popups (proves popups, sliders, event subscriptions).
4. battery, media, idle-inhibitor, updates, wireless, bluetooth (zbus
   + subprocess patterns).
5. PanelBase + settings panel + profiles.
6. Panels: power, wallpaper, recording.
7. Notifications last (biggest single module; daemon takeover needs
   the rest stable).
8. Flip `dshell`/service defaults, retire quickshell, update wiki.

## Verification (every step)

- RSS budget: `grep VmRSS /proc/$(pgrep dotshell)/status` idle and
  after opening/closing every panel twice (leak check).
- All seven sway binds + `dshell --complete` round-trips.
- Keymap parity checklist per surface (each module plan carries its
  own list).
- `dshell` reads with the daemon stopped (`wallpaper restore`,
  `profile current`, `theme list`).
