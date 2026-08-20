#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/modules/display/bin/display-text-size"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

export XDG_CONFIG_HOME="$sandbox/config"
mkdir -p "$XDG_CONFIG_HOME"/{alacritty,kitty,ghostty,foot} "$sandbox/bin"

cat >"$sandbox/bin/gsettings" <<'SH'
#!/usr/bin/env bash
[[ $1 != get ]] || printf "'Adwaita Sans 11'\n"
SH
cat >"$sandbox/bin/pkill" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$sandbox/bin/pgrep" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$sandbox/bin"/*
export PATH="$sandbox/bin:$PATH"

printf 'size = 9\n' >"$XDG_CONFIG_HOME/alacritty/alacritty.toml"
printf 'font_size 9.0\n' >"$XDG_CONFIG_HOME/kitty/kitty.conf"
printf 'font-size = 9\n' >"$XDG_CONFIG_HOME/ghostty/config"
printf 'font=monospace:size=9\n' >"$XDG_CONFIG_HOME/foot/foot.ini"

assert_terminal_size() {
  "$script" "$1"
  grep -Fxq "size = $2" "$XDG_CONFIG_HOME/alacritty/alacritty.toml"
  grep -Fxq "font_size $2.0" "$XDG_CONFIG_HOME/kitty/kitty.conf"
  grep -Fxq "font-size = $2" "$XDG_CONFIG_HOME/ghostty/config"
  grep -Fxq "font=monospace:size=$2" "$XDG_CONFIG_HOME/foot/foot.ini"
}

for size in 10 11 12 14; do
  assert_terminal_size "$size" 14
done
assert_terminal_size 9 10
assert_terminal_size 16 16
assert_terminal_size 20 18

echo 'display text size conversion tests passed'
