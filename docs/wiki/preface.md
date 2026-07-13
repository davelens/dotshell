[Back to wiki](./index.md)

# Preface

dotshell is a personal desktop shell built on
[Quickshell](https://quickshell.outfoxxed.me) (QML) for wlroots
compositors — sway and niri are supported. It provides a statusbar,
popups, full-screen overlay panels (settings, notifications, wallpaper
browser, screen recording files, power menu), a notification daemon,
theming with GTK 4 sync, and profile-scoped state.

The repo is symlinked to `~/.config/dotshell`. It runs through the
`dotshell.service` systemd user unit on Arch or the turnstile-managed
`dotshell` runit user service on Void. Features live as self-contained,
pluggable modules under `modules/`; the `dshell` CLI (`bin/dshell`) is the
scripted/keybound entry point.
