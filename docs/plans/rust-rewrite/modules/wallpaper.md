# wallpaper — Rust rewrite plan

Ports `modules/wallpaper/` (Manager + Button + Panel + Settings,
~1828 lines QML). Local wallpaper browser + wallhaven.cc search and
download, apply via sway/swaybg.

## Feature parity

- **Panel** (`PanelBase`, overlay id `wallpaper`): two tabs —
  `local` (files in the wallpapers dir, grid, delete) and `browse`
  (wallhaven search results, pagination, download+set).
- **Apply**: sway → `swaymsg output * bg <path> fill`; niri/others →
  managed `swaybg` (`pkill -x swaybg`, respawn `swaybg -o '*' -i
  <path> -m fill`). Identical, via the Compositor backend check.
- **Persisted current wallpaper** in the module state file — this is
  what `dshell wallpaper restore` reads at compositor startup
  (bash + `json_get`, shell down), so the schema is frozen.
- Settings page (wallhaven options / dirs) unchanged.

## Stack

- Module crate with manager + button + settings, root component
  `Panel` (order 45).
- wallhaven API + downloads: `reqwest` (rustls) on the tokio sidecar,
  replacing the `curl` calls — the current download line interpolates
  the path into `sh -c` (pre-ADR-0001 code); the port fixes that for
  free. Same query params, same JSON parsing (`serde`).
- Thumbnails: `image` crate, on-disk cache keyed by path+mtime
  (local) / wallhaven thumb URL (browse), generated off the render
  loop, placeholder tiles until ready.
- Apply path: `collect_output` argv calls exactly as listed above.

## State

- Same file, same schema (frozen by `dshell wallpaper restore`).

## IPC / dshell (unchanged)

- `dshell wallpaper browser toggle|open|close` → `overlay` target,
  id `wallpaper`.
- `wallpaper set(path)` IPC verb on target `wallpaper` (used by
  `dshell wallpaper set`, which also has a shell-down fallback path).
- `dshell wallpaper set/restore` local-fn logic in bash stays
  untouched.
- Sway bind: `mod4+Shift+w` → `dshell wallpaper browser toggle`.

## Keymaps (exact, from `Panel.qml`)

- `Escape` / `q` / `Ctrl+[` close.
- `h`/`j`/`k`/`l` grid navigation.
- `Ctrl+h` / `Ctrl+l` tab switch (local ↔ browse).
- `Ctrl+n` / `Ctrl+p` and `Ctrl+j` / `Ctrl+k` next/previous.
- `Ctrl+f` focus search field.
- `n` / `p` (without Ctrl, browse tab only) next/previous results
  page.
- `d` (local tab only) delete with confirmation.
- `Space` select/preview; `Return`/`Enter` set wallpaper.

## Verification

- Set from local tab on sway and niri; search+download+set from
  browse tab; `dshell wallpaper restore` with the daemon stopped
  still applies the last wallpaper; keyboard-only full session.
