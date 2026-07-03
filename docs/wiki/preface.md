[Back to wiki](./index.md)

# Preface

dotshell is a personal desktop shell built on
[Quickshell](https://quickshell.outfoxxed.me) (QML) for wlroots
compositors — sway and niri are supported. It provides a statusbar,
popups, full-screen overlay panels (settings, notifications, wallpaper
browser, screen recording files, power menu), a notification daemon,
theming with GTK 4 sync, and profile-scoped state.

The repo is symlinked to `~/.config/dotshell` and runs as the
`quickshell.service` user unit (`setup/quickshell.service`). Features
live as self-contained, pluggable modules under `modules/`; the
`dshell` CLI (`bin/dshell`) is the scripted/keybound entry point.
