import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  PwObjectTracker {
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  property var sink: Pipewire.defaultAudioSink
  property real volume: sink && sink.audio ? sink.audio.volume : 0
  property bool muted: sink && sink.audio ? sink.audio.muted : false

  popupId: "volume"
  icon: getVolumeIcon(volume, muted)
  iconSize: 24
  iconColor: muted ? Theme.textMuted : Theme.textPrimary

  function getVolumeIcon(volume, muted) {
    if (muted || volume === 0) return "󰝟"
    if (volume < 0.25) return "󰕿"
    if (volume < 0.50) return "󰖀"
    return "󰕾"
  }

  onWheel: event => {
    if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
      var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
      Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, Pipewire.defaultAudioSink.audio.volume + delta))
    }
  }
}
