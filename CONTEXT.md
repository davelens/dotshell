# Domain language

Terms used consistently across code and docs. Keep this list short and exact.

- **Module** — a drop-in folder under `modules/` with a `module.json` manifest.
  Modules must be self-contained: dropping the folder in (plus its manifest)
  is all that's required to register bar components, popups, and settings.
- **Module id** — declared once, in `module.json`. Never restate it in module
  QML: shell.qml injects it into popups (`ModulePopup.moduleId`) and bar
  buttons (`BarButton.popupId`) at creation time.
- **ModulePopup** — the host for a module's popup window
  (`core/components/ModulePopup.qml`). Owns the open-state check and the
  primary-screen instantiation; the module's `Popup.qml` declares only a
  `PopupBase` delegate with content.
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
- **Overlay** — a full-screen surface: slide-in panel (notifications,
  recording, wallpaper), power menu, or the settings panel. Identity lives
  in **OverlayManager** (`core/OverlayManager.qml`): at most one overlay is
  active; opening one closes the active popup and any other overlay, and
  bar focus watches its single `overlayOpen` signal. Managers bind their
  open state to `OverlayManager.isOpen(id)` and route open/close/toggle
  through it. `open(id, context)` carries payloads (e.g. a settings
  category); `opened(id)` fires on every open, including re-opens.
- **PanelBase** — the full-screen overlay window scaffold
  (`core/components/PanelBase.qml`): covers the screen, ignores exclusion
  zones, exclusive keyboard focus, compositor namespace via
  `namespaceName`. Used by recording/wallpaper/power/settings; the
  notifications panel keeps its own latched window for slide animation.
- **SettingsPage** — the scaffold for module settings pages
  (`core/components/SettingsPage.qml`): scroll chrome, optional `title`,
  `contentSpacing`, `searchQuery`, and search highlighting. The highlight
  markup itself is produced once by `Theme.highlightText(text, query)`;
  pages render it with `Text.RichText`.
- **Profile** — a named directory of profile-scoped state files under the
  data dir, managed by `GeneralSettings`. The first-run profile is named
  `defaults` (directory name), displayed as "Default".
