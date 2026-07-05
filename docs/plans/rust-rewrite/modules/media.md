# media — Rust rewrite plan

Ports `modules/media/` (Segment only, ~97 lines QML). Track display +
play/pause toggle, today on `Quickshell.Services.Mpris`.

## Feature parity

- Segment shows the active player's track (title/artist truncation
  rules as today), hidden when no player.
- Click / bar-focus-mode activate toggles play/pause on the active
  player (segment with `activate()` — focus mode `Space`/`Return`/
  `Enter` runs it, as today).
- Player selection semantics preserved (first/most-recent active
  player, matching current Quickshell.Mpris behavior observed at port
  time).

## Stack

- Module crate, segment only (order 130).
- MPRIS over `zbus`: watch `org.freedesktop.DBus` `NameOwnerChanged`
  for `org.mpris.MediaPlayer2.*` names; per player, proxy
  `org.mpris.MediaPlayer2.Player` (`Metadata`, `PlaybackStatus`,
  `PlayPause()`), subscribe `PropertiesChanged`. Hand-rolled proxies —
  event-driven, no polling, no extra crate.

## State / IPC

- None.

## Verification

- Play something in Spotify and a browser: segment tracks the right
  player, click toggles it; kill the player → segment hides.
