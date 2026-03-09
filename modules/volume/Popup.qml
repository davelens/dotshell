import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import "../.."
import "../../core/components"

Variants {
  id: volumePopup

  model: PopupManager.isOpen("volume") && ScreenManager.primaryScreen
         ? [ScreenManager.primaryScreen] : []

  property var sink: Pipewire.defaultAudioSink
  property real volume: sink && sink.audio ? sink.audio.volume : 0
  property bool muted: sink && sink.audio ? sink.audio.muted : false

  property var audioSinks: {
    var sinks = []
    if (Pipewire.ready && Pipewire.nodes && Pipewire.nodes.values) {
      var nodes = Pipewire.nodes.values
      for (var i = 0; i < nodes.length; i++) {
        var node = nodes[i]
        if (node.audio && node.isSink && !node.isStream) {
          sinks.push(node)
        }
      }
    }
    return sinks
  }

  property var audioSources: {
    var sources = []
    if (Pipewire.ready && Pipewire.nodes && Pipewire.nodes.values) {
      var nodes = Pipewire.nodes.values
      for (var i = 0; i < nodes.length; i++) {
        var node = nodes[i]
        if (node.audio && !node.isSink && !node.isStream) {
          sources.push(node)
        }
      }
    }
    return sources
  }

  PopupBase {
    id: popupBase
    popupWidth: 360

    property var currentSink: Pipewire.defaultAudioSink
    property var currentSource: Pipewire.defaultAudioSource

    function setDefaultSink(item) {
      currentSink = item
      Pipewire.preferredDefaultAudioSink = item
      sinkProcess.command = ["wpctl", "set-default", String(item.id)]
      sinkProcess.running = true
    }

    function setDefaultSource(item) {
      currentSource = item
      Pipewire.preferredDefaultAudioSource = item
      sourceProcess.command = ["wpctl", "set-default", String(item.id)]
      sourceProcess.running = true
    }

    Process { id: sinkProcess }
    Process { id: sourceProcess }

    // Volume slider
    Row {
      width: parent.width
      height: 32
      spacing: 8

      property var sink: Pipewire.defaultAudioSink
      property real volume: sink && sink.audio ? sink.audio.volume : 0
      property bool muted: sink && sink.audio ? sink.audio.muted : false

      FocusIconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: parent.muted ? "󰝟" : "󰕾"
        iconColor: parent.muted ? Theme.danger : Theme.textPrimary
        hoverColor: parent.muted ? Theme.danger : Theme.accent
        iconSize: 20
        onClicked: {
          if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
          }
        }
      }

      FocusSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 28 - 44 - 16
        height: 20
        from: 0
        to: 1
        stepSize: 0.02
        value: parent.volume
        accentColor: Theme.accent
        trackColor: Theme.bgCard
        trackHeight: 8
        handleSize: 14
        onMoved: {
          if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
            Pipewire.defaultAudioSink.audio.volume = value
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(parent.volume * 100) + "%"
        color: Theme.accent
        font.pixelSize: 16
        width: 44
        horizontalAlignment: Text.AlignRight
      }
    }

    // Output devices
    Dropdown {
      width: parent.width
      items: volumePopup.audioSinks
      currentItem: popupBase.currentSink
      headerIcon: "󰓃"
      headerLabel: "Output"
      textRole: "description"
      valueRole: "id"
      onItemSelected: item => popupBase.setDefaultSink(item)
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
    }

    // Input devices
    Dropdown {
      width: parent.width
      items: volumePopup.audioSources
      currentItem: popupBase.currentSource
      headerIcon: "󰍬"
      headerLabel: "Input"
      textRole: "description"
      valueRole: "id"
      onItemSelected: item => popupBase.setDefaultSource(item)
    }
  }
}
