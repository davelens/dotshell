#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/modules/volume/bin/volume-set-default"
popup="$repo_root/modules/volume/Popup.qml"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

export CALL_LOG="$sandbox/calls"
mkdir -p "$sandbox/bin"
: >"$CALL_LOG"

cat >"$sandbox/bin/wpctl" <<'SH'
#!/usr/bin/env bash
printf 'wpctl %s\n' "$*" >>"$CALL_LOG"
SH

cat >"$sandbox/bin/pactl" <<'SH'
#!/usr/bin/env bash
printf 'pactl %s\n' "$*" >>"$CALL_LOG"
case "$*" in
  'list sink-inputs')
    printf '%s\n' \
      'Sink Input #12' '    application.name = "Firefox"' \
      'Sink Input #98' '    application.name = "EasyEffects"' \
      'Sink Input #99' '    node.name = "filter-chain"' \
      'Sink Input #13' '    application.name = "Chromium"'
    ;;
  'list short source-outputs') printf '21\trecorder\n' ;;
esac
SH

chmod +x "$sandbox/bin/wpctl" "$sandbox/bin/pactl"
export PATH="$sandbox/bin:$PATH"

"$script" sink 42 speakers
[[ $(<"$CALL_LOG") == $'wpctl set-default 42\npactl set-default-sink speakers\npactl list sink-inputs\npactl move-sink-input 12 speakers\npactl move-sink-input 13 speakers' ]]
printf 'ok - output selection moves application streams without rewiring DSP streams\n'

: >"$CALL_LOG"
"$script" source 43 microphone
[[ $(<"$CALL_LOG") == $'wpctl set-default 43\npactl set-default-source microphone\npactl list short source-outputs\npactl move-source-output 21 microphone' ]]
printf 'ok - input selection moves active recording streams\n'

grep -Fq 'currentItem: Pipewire.defaultAudioSink' "$popup"
grep -Fq 'currentItem: Pipewire.defaultAudioSource' "$popup"
grep -Fq 'Pipewire.defaultAudioSource.audio.volume = value' "$popup"
grep -Fq 'Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted' "$popup"
printf 'ok - popup follows defaults and controls input volume and mute\n'
