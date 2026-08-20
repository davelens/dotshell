[Back to core](./index.md)

# Theming

A theme is a flat JSON map with 19 required semantic color tokens and
optional `fontFamily` and `fontSizeBody` typography tokens. The `Theme`
singleton exposes them as properties that components bind to, so theme
switches repaint live.

`core/Theme.qml`

## Tokens

Backgrounds `bgBase bgBaseAlt bgDeep bgCard bgCardHover bgBorder` ·
text `textPrimary textSecondary textTertiary textMuted textSubtle` ·
semantic `accent success warning danger focusRing activeIndicator
overlay knob`.

Typography defaults to `fontFamily: "Hack Nerd Font"` and
`fontSizeBody: 14`. `fontFamily` applies throughout dotshell, including
notifications; `fontSizeBody` remains consumed by `TooltipText` only.
`Symbols Nerd Font` glyph renderers and `KeyboardTag`'s special font are
deliberate exceptions.

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

Drop `<name>.json` with all 19 color tokens into either themes dir.
Optionally add `fontFamily` as a non-empty string and `fontSizeBody` as a
positive finite number. No registration; `dshell theme list`/completion
pick it up from the filesystem.
