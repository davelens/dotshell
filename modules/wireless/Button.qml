import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  popupId: "wireless"

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
    visible: button.hovered && WirelessManager.connectedNetwork && !button.popupManager.isOpen("wireless")
    fixedWidth: 260

    Column {
      spacing: 2

      Text {
        text: "Connected to " + (WirelessManager.connectedNetwork ? WirelessManager.connectedNetwork.ssid : "")
        color: Theme.textPrimary
        font.pixelSize: 13
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        text: "Uptime: " + WirelessManager.getConnectionDurationLong()
        color: Theme.textMuted
        font.pixelSize: 12
      }

      Row {
        spacing: 16

        Text {
          text: "Down: " + WirelessManager.formatSpeed(WirelessManager.downloadSpeed)
          color: Theme.textMuted
          font.pixelSize: 12
        }

        Text {
          text: "Up: " + WirelessManager.formatSpeed(WirelessManager.uploadSpeed)
          color: Theme.textMuted
          font.pixelSize: 12
        }
      }
    }
  }
}
