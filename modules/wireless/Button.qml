import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  // Force reactive update by depending on the properties that affect the icon
  icon: {
    var _ = WirelessManager.enabled
    var __ = WirelessManager.connectedNetwork
    return WirelessManager.getIcon()
  }
  iconColor: WirelessManager.enabled ? Theme.textPrimary : Theme.textMuted

  // Bar icon tooltip
  TooltipBase {
    anchorItem: button
    visible: button.hovered && WirelessManager.connectedNetwork && !button.popupManager.isOpen(button.popupId)
    Column {
      spacing: 4

      Text {
        text: "Connected to " + (WirelessManager.connectedNetwork ? WirelessManager.connectedNetwork.ssid : "")
        color: Theme.textPrimary
        font.pixelSize: 14
      }

      Text {
        text: "Uptime: " + WirelessManager.getConnectionDurationLong()
        color: Theme.textPrimary
        font.pixelSize: 14
      }

      Row {
        spacing: 16

        Text {
          text: "Down: " + WirelessManager.formatSpeed(WirelessManager.downloadSpeed)
          color: Theme.textPrimary
          font.pixelSize: 14
        }

        Text {
          text: "Up: " + WirelessManager.formatSpeed(WirelessManager.uploadSpeed)
          color: Theme.textPrimary
          font.pixelSize: 14
        }
      }
    }
  }
}
