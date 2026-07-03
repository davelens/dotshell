[Back to core](./index.md)

# Theming

A theme is a flat JSON map of 19 semantic color tokens. The `Theme`
singleton exposes them as `property color`s that every component binds
to, so theme switches repaint live.

`core/Theme.qml`

## Tokens

Backgrounds `bgBase bgBaseAlt bgDeep bgCard bgCardHover bgBorder` ·
text `textPrimary textSecondary textTertiary textMuted textSubtle` ·
semantic `accent success warning danger focusRing activeIndicator
overlay knob`.

## Resolution

Active theme name comes from `GeneralSettings.theme` (persisted in
`general.json`). Two candidate files are watched with live reload:

1. `$XDG_DATA_HOME/dotshell/themes/<name>.json` — user override, wins
2. `<shellDir>/themes/<name>.json` — bundled

Missing user file falls back to bundled; editing either file on disk
re-applies immediately (`watchChanges`). `dshell theme list` shows both
sources with the same precedence.

## GTK 4 sync

`bin/generate-gtk-css <theme-json>` writes
`~/.config/gtk-4.0/gtk.css`, mapping the tokens onto libadwaita
`@define-color` names so GTK apps match the shell. It runs on
`dshell theme set` and `dshell theme refresh` **only** — changing the
theme through the settings UI does not regenerate GTK CSS (known gap;
run `dshell theme refresh` after).

## Adding a theme

Drop `<name>.json` with all 19 tokens into either themes dir. No
registration; `dshell theme list`/completion pick it up from the
filesystem.
