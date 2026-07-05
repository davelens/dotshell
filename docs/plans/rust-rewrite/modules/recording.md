# recording — Rust rewrite plan

Ports `modules/recording/` (Manager + Button + Panel + Settings,
~1848 lines QML). gpu-screen-recorder lifecycle + a keyboard-driven
file browser for screencasts/screenshots.

## Feature parity

- **Recording control**: start/stop via the configured process name
  (default `gpu-screen-recorder`, editable in Settings), liveness via
  `pidof`, stop via `pkill`/`wait-recording` semantics as today; bar
  button reflects recording state (record glyph 󰑊 + active styling).
- **Files panel** (`PanelBase`, overlay id `recording`): grid browser
  over `~/Videos/screencasts/` (and screenshots dir), newest-first,
  metadata via `ffprobe`, open/preview via the same external viewer
  used today (`sushi`), copy path via `wl-copy` (including the
  "latest screencast to clipboard" helper), rename via `mv`, delete
  via `rm` with confirmation.
- **Settings page**: process name and current options unchanged.

## Stack

- Module crate with manager + button + settings, root component
  `Panel` (order 5).
- All external tools stay subprocesses (`collect_output`, argv
  arrays — the current `bash -c` string builds get cleaned up to argv
  in the port, per ADR-0001).
- Video thumbnails: extract one frame per file (`ffmpeg`/`ffprobe`,
  already dependencies) into an on-disk cache keyed by
  path+mtime; screenshots thumbnail via the `image` crate, same
  cache. Generation happens off the render loop (tokio sidecar),
  placeholder tile until ready.

## State

- Same state file under the `recording` id (adapter mode, same fields
  incl. `processName`).

## IPC / dshell (unchanged)

- `dshell screen-recording files toggle|open|close` → `overlay`
  target, id `recording`.
- Sway bind: `mod4+Shift+s` → `dshell screen-recording files toggle`.

## Keymaps (exact, from `Panel.qml` — richest surface in the shell)

- `Escape` / `q` close; `Ctrl+[` close.
- `h`/`j`/`k`/`l` grid navigation.
- `Ctrl+h` / `Ctrl+l` switch tabs (recordings ↔ screenshots).
- `Ctrl+n` / `Ctrl+p` and `Ctrl+j` / `Ctrl+k` next/previous
  (list-order variants, exactly as currently bound).
- `Ctrl+f` filter/search field focus.
- `d` delete (with confirm dialog: `DialogOverlay` keys).
- `Space` preview/select; `Return`/`Enter` open.
- Transcribe the full `Keys.onPressed` chains 1:1 at port time —
  this panel is the reference test for the keymap engine.

## Verification

- Record → stop → file appears in panel with thumbnail; full
  keyboard-only session: open panel via bind, filter, navigate, copy
  path, delete a file; tab switch; thumbnails survive a cache wipe.
