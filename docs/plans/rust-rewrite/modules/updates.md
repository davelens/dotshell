# updates — Rust rewrite plan

Ports `modules/updates/` (Manager + Button + Popup + Settings,
~1109 lines QML). Pending pacman/AUR/flatpak update counts and lists.

## Feature parity

- Three sources, same commands verbatim (they are the contract with
  the Arch tooling):
  - repo: `checkupdates | grep -Fw -f <(pacman -Qqe)` (explicit only)
  - AUR: `paru -Qua | grep -Fw -f <(pacman -Qqem)`
  - flatpak: `flatpak remote-ls --updates --app
    --columns=name,application,version`
- Periodic checks on the configured interval; bar button shows
  count/available-state; popup lists packages per source with
  current→new versions.
- Settings page: intervals / enabled sources, unchanged.

## Stack

- Module crate with manager + button + popup + settings (order 15).
- The two pipeline commands keep their `bash -c` form — they are
  fixed strings with no interpolated values, which ADR-0001 permits.
  Run via `collect_output` on the tokio sidecar (checkupdates can take
  seconds; never block the render loop). Parse into typed rows.

## State

- Same state file under the `updates` id, adapter mode, same fields
  and defaults (interval etc.).

## IPC / dshell

- No module-owned verbs. `dshell popup toggle updates` reaches it via
  the generic `popup` target.
- Sway bind: `$mod+Shift+u` → `dshell popup toggle updates`. This is
  the canonical test for the stemless-popup rule: with the updates
  button disabled in the bar, the IPC-opened popup anchors to the
  primary screen's right edge minus 20px, draws no stem, square
  top-right corner.

## Keymaps

- Popup: `Escape`/`q`/`Ctrl+[` close, `Ctrl+n`/`Ctrl+p` scroll/focus
  through entries — standard `PopupBase` set.

## Verification

- Counts match the raw commands run by hand; `$mod+Shift+u` with the
  bar button enabled (stem) and disabled (stemless fallback); a
  source erroring (no network) shows the same degraded state as
  today.
