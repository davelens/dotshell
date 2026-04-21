import QtQuick
import qs
import qs.core.components

Item {
  id: root

  property var screen
  property bool barFocused: false

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: label.width + 16
  implicitHeight: label.height + 8

  // Color coding based on power level
  readonly property string _powerColor: {
    if (PowerMeterManager.totalPowerW <= 100) return "#4ade80"   // green - low load
    if (PowerMeterManager.totalPowerW <= 200) return "#facc15"   // yellow - moderate
    return "#ef4444"                                               // red - high (>200W)
  }

  // Tooltip breakdown
  readonly property string _tooltipText: {
    var parts = []
    if (PowerMeterManager.gpuAvailable) {
      parts.push("GPU: " + Math.round(PowerMeterManager.gpuPowerMw / 1000) + " W")
    } else {
      parts.push("GPU: —")
    }
    if (PowerMeterManager.raplAvailable) {
      parts.push("CPU: " + Math.round(PowerMeterManager.cpuPowerMw / 1000) + " W")
    } else {
      parts.push("CPU: —")
    }
    parts.push("Base: ~" + Math.round(PowerMeterManager.basePowerMw / 1000) + " W")
    parts.push("Total: " + PowerMeterManager.totalPowerW + " W")
    return parts.join("\n")
  }

  // Only show if we have at least one data source
  readonly property bool _hasData: PowerMeterManager.gpuAvailable || PowerMeterManager.raplAvailable

  Text {
    id: label
    anchors.centerIn: parent
    text: "⚡ " + (PowerMeterManager.totalPowerW > 0 ? PowerMeterManager.totalPowerW + " W" : "—")
    font.pixelSize: 14
    color: _powerColor
    visible: _hasData && PowerMeterManager.totalPowerW > 0
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
  }

  TooltipBase {
    anchorItem: root
    visible: hoverArea.containsMouse || barFocused

    Text {
      color: Theme.textPrimary
      font.pixelSize: 14
      text: _tooltipText
    }
  }
}
