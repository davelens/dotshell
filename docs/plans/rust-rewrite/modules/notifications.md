# notifications — Rust rewrite plan

Ports `modules/notifications/` (Manager + Button + Card + Panel +
Popups + Settings, ~1806 lines QML — the biggest module). The shell
**is** the notification daemon. Port last (core plan step 7).

## Feature parity

- **Daemon**: own `org.freedesktop.Notifications` on the session bus:
  `Notify` (including `replaces_id` in-place updates —
  `updatePopup`), `CloseNotification`, `GetCapabilities`,
  `GetServerInformation`, signals `NotificationClosed` and
  `ActionInvoked`. Actions: default-action invoke, named actions,
  `focusAppWindow` via the core Compositor (`focus_window(app_id)`).
- **Toasts** (`Popups.qml` root component): stacked popup windows,
  auto-dismiss after `popupTimeout` (default 6000ms), per-toast
  dismiss/expire distinction, app icon / image / body rendering.
- **History**: grouped by app, capped at `maxHistorySize` (default
  100), unread count on the bar button badge.
- **DND**: manual toggle + schedule (`dndStartHour/Minute` →
  `dndEndHour/Minute`, 15-minute steps, defaults 21:00→08:00),
  `criticalBypassDnd` (default true). Button icons 󰂚 / 󰂠 per state.
- **Panel**: slide-in history panel. Note: it keeps its own latched
  window for the slide animation instead of `PanelBase` — preserve
  that (own layer surface + animation), registered as overlay
  `notifications`.
- **Settings page**: timeout, history size, DND schedule with
  `TimePicker`s, critical bypass.

## Stack

- Module crate with manager + button + settings, root components
  `Panel` + `Popups` (order 30).
- Daemon: `zbus` server, request the well-known name (fail loudly if
  mako/dunst holds it — same conflict semantics as today).
- Icons/images: hints (`image-data`, `image-path`, `icon_name`) via
  `image` crate; themed icon lookup via the `freedesktop-icons` crate;
  same resolution order as `getAppIcon`/`getImage`.
- DND schedule evaluation off the core `Time` tick.

## State

- Adapter-mode struct, same field names and defaults as the
  `settingsAdapter` today; history is runtime-only (as today).

## IPC / dshell (unchanged surface)

- Overlay verbs: `notifications toggle|open|close` → `overlay`
  target.
- Module verbs on target `notifications`: `dismiss(id)`,
  `clearAll()` → `dshell notifications dismiss <id>` /
  `clear-all`. Feedback and `error:` conventions identical.

## Keymaps (exact)

- Sway bind: `$mod+Shift+n` → `dshell notifications toggle`.
- Panel: `Escape`/`q`/`Ctrl+[` close; `Ctrl+n`/`Ctrl+p`
  next/previous card; `c` (without Ctrl) clear.
- Card (compact): `y` copy notification content.
- Card actions/buttons: `Space`/`Return`/`Enter` activate.

## Risks

- Daemon takeover ordering at login (service must be up before the
  first notification); mirror current systemd unit ordering.
- `replaces_id` + expire/dismiss races are the fiddly part; unit-test
  the popup model against recorded `notify-send` sequences (the
  settings page's test-notification button exercises this too).

## Verification

- `notify-send` basics, `replaces_id` update (e.g. volume OSD apps),
  action invocation focuses the sender's window; DND window
  suppresses non-critical toasts but critical passes; history cap;
  `dshell notifications dismiss <id>` / `clear-all` feedback strings
  match current output.
