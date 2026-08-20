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
    fixedWidth: 300

    Column {
      width: parent.width
      spacing: 4

      TooltipText {
        width: parent.width
        text: "Connected to " + (WirelessManager.connectedNetwork ? WirelessManager.connectedNetwork.ssid : "")
        elide: Text.ElideRight
      }

      TooltipText {
        text: "Uptime: " + WirelessManager.getConnectionDurationLong()
      }

      Row {
        spacing: 16

        TooltipText {
          text: "Down: " + WirelessManager.formatSpeed(WirelessManager.downloadSpeed)
        }

        TooltipText {
          text: "Up: " + WirelessManager.formatSpeed(WirelessManager.uploadSpeed)
        }
      }
    }
  }
}
