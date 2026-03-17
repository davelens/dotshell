import QtQuick
import Quickshell.Services.UPower
import qs
import qs.core.components

Item {
  id: battery
  property var screen
  property bool barFocused: false

  anchors.verticalCenter: parent.verticalCenter
  width: batteryRow.width
  height: batteryRow.height
  // Hide when: no device, not ready, fully charged (100%), or no real battery
  // (0% + not charging = desktop with no battery hardware)
  property bool showInBar: {
    if (!UPower.displayDevice || !UPower.displayDevice.ready) return false
    var pct = Math.round(battery.percentage)
    if (pct >= 100) return false
    if (pct <= 0 && !battery.charging) return false
    return true
  }

  property real percentage: UPower.displayDevice ? UPower.displayDevice.percentage * 100 : 0
  property int batteryState: UPower.displayDevice ? UPower.displayDevice.state : 0
  property bool charging: batteryState === 1
  property bool fullyCharged: batteryState === 4
  property real changeRate: UPower.displayDevice ? UPower.displayDevice.changeRate : 0
  property real timeToEmpty: UPower.displayDevice ? UPower.displayDevice.timeToEmpty : 0
  property real timeToFull: UPower.displayDevice ? UPower.displayDevice.timeToFull : 0

  function formatTime(seconds) {
    if (seconds <= 0) return ""
    var h = Math.floor(seconds / 3600)
    var m = Math.floor((seconds % 3600) / 60)
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  function getBatteryIcon(percentage, charging, fullyCharged) {
    if (charging) return "󰂄"
    if (fullyCharged) return "󰂅"
    if (percentage >= 90) return "󰁹"
    if (percentage >= 80) return "󰂂"
    if (percentage >= 70) return "󰂁"
    if (percentage >= 60) return "󰂀"
    if (percentage >= 50) return "󰁿"
    if (percentage >= 40) return "󰁾"
    if (percentage >= 30) return "󰁽"
    if (percentage >= 20) return "󰁼"
    if (percentage >= 10) return "󰁻"
    return "󰂃"
  }

  function getBatteryColor(percentage, charging, fullyCharged) {
    if (charging || fullyCharged) return Theme.success
    if (percentage <= 10) return Theme.danger
    if (percentage <= 25) return Theme.warning
    if (percentage <= 50) return Theme.warning
    return Theme.success
  }

  Row {
    id: batteryRow
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: battery.getBatteryIcon(battery.percentage, battery.charging, battery.fullyCharged)
      color: battery.getBatteryColor(battery.percentage, battery.charging, battery.fullyCharged)
      font.pixelSize: 18
      font.family: "Symbols Nerd Font"
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(battery.percentage) + "%"
      color: Theme.textPrimary
      font.pixelSize: 14
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
  }

  // Tooltip
  TooltipBase {
    anchorItem: battery
    visible: hoverArea.containsMouse || battery.barFocused

    Text {
      color: Theme.textPrimary
      font.pixelSize: 14

      text: {
        var rate = Math.abs(battery.changeRate)
        var parts = []

        if (battery.fullyCharged) {
          parts.push("Fully charged")
        } else if (battery.charging) {
          if (rate > 0) parts.push(rate.toFixed(1) + " W")
          if (battery.timeToFull > 0) {
            parts.push(battery.formatTime(battery.timeToFull) + " until full")
          }
        } else {
          if (rate > 0) parts.push(rate.toFixed(1) + " W")
          if (battery.timeToEmpty > 0) {
            parts.push(battery.formatTime(battery.timeToEmpty) + " remaining")
          }
        }

        return parts.length > 0 ? parts.join("  ·  ") : "On AC power"
      }
    }
  }
}
