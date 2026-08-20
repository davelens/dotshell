#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/modules/display/bin/display-brightness"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

export XDG_RUNTIME_DIR="$sandbox/runtime"
export DISPLAY_BRIGHTNESS_BACKLIGHT_PATH="$sandbox/backlight"
export CALL_LOG="$sandbox/calls"
mkdir -p "$XDG_RUNTIME_DIR" "$DISPLAY_BRIGHTNESS_BACKLIGHT_PATH" "$sandbox/bin"
: >"$CALL_LOG"

cat >"$sandbox/bin/brightnessctl" <<'SH'
#!/usr/bin/env bash
printf 'brightnessctl %s\n' "$*" >>"$CALL_LOG"
if [[ $* == *" -m" ]]; then
  printf '%s,backlight,42,42%%,100\n' "$2"
fi
SH

cat >"$sandbox/bin/ddcutil" <<'SH'
#!/usr/bin/env bash
printf 'ddcutil %s\n' "$*" >>"$CALL_LOG"
case " $* " in
  *" detect --brief "*)
    printf 'Display 1\n  I2C bus: /dev/i2c-7\n  DRM connector: card2-DP-1\n'
    ;;
  *" getvcp 10 --brief "*)
    printf 'VCP 10 C 40 80\n'
    ;;
esac
SH
chmod +x "$sandbox/bin/brightnessctl" "$sandbox/bin/ddcutil"
export PATH="$sandbox/bin:$PATH"

reset_backlights() {
  rm -rf "$DISPLAY_BRIGHTNESS_BACKLIGHT_PATH"
  mkdir -p "$DISPLAY_BRIGHTNESS_BACKLIGHT_PATH"
  local device
  for device in "$@"; do mkdir -p "$DISPLAY_BRIGHTNESS_BACKLIGHT_PATH/$device"; done
}

assert_device() {
  local expected="$1" description="$2"
  shift 2
  reset_backlights "$@"
  : >"$CALL_LOG"
  [[ $($script get eDP-1) == 42 ]]
  grep -Fq "brightnessctl -d $expected -m" "$CALL_LOG"
  printf 'ok - %s\n' "$description"
}

assert_device gmux_backlight 'gmux backlight has highest priority' \
  intel_backlight amdgpu_bl0 gmux_backlight
assert_device amdgpu_bl1 'AMDGPU backlight beats Intel' \
  intel_backlight amdgpu_bl1
assert_device intel_backlight 'Intel backlight beats NVIDIA' \
  nvidia_wmi_ec_backlight intel_backlight
assert_device nvidia_wmi_ec_backlight 'NVIDIA backlight beats fallback devices' \
  acpi_video0 nvidia_wmi_ec_backlight
assert_device panel_backlight 'a real fallback excludes the Apple Touch Bar' \
  appletb_backlight panel_backlight

rm -rf "$XDG_RUNTIME_DIR/dotshell-display-brightness"
: >"$CALL_LOG"
[[ $($script get DP-1) == 50 ]]
[[ $($script get DP-1) == 50 ]]
[[ $(grep -c 'ddcutil --skip-ddc-checks detect --brief' "$CALL_LOG") == 1 ]]
printf 'ok - DRM connector mapping is normalized and cached\n'

"$script" set DP-1 25 >/dev/null
grep -Fq 'ddcutil --bus 7 --skip-ddc-checks --noverify setvcp 10 20' "$CALL_LOG"
printf 'ok - monitor VCP maximum converts percentages and write flags are safe\n'

before="$(grep -c 'ddcutil --skip-ddc-checks detect --brief' "$CALL_LOG")"
if "$script" get DP-2 >/dev/null 2>&1; then exit 1; fi
if "$script" get DP-2 >/dev/null 2>&1; then exit 1; fi
after="$(grep -c 'ddcutil --skip-ddc-checks detect --brief' "$CALL_LOG")"
[[ $after == $((before + 1)) ]]
grep -Eq '^unavailable [0-9]+$' \
  "$XDG_RUNTIME_DIR/dotshell-display-brightness/DP-2.bus"
printf 'ok - unavailable connectors use the negative cache\n'
