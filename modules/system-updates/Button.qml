import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  property bool showInBar: SystemUpdatesManager.totalCount > 0

  icon: SystemUpdatesManager.getIcon()
  iconColor: Theme.success

  TooltipBase {
    anchorItem: button
    visible: button.hovered && !button.popupManager.isOpen(button.popupId) && button.visible

    Column {
      spacing: 2

      Text {
        visible: SystemUpdatesManager.checking || SystemUpdatesManager.totalCount === 0
        text: SystemUpdatesManager.checking ? "Checking for updates..." : "System up to date"
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: SystemUpdatesManager.repoUpdates.length > 0
        text: SystemUpdatesManager.repoUpdates.length + " " + SystemUpdatesManager.repoLabel + " update"
          + (SystemUpdatesManager.repoUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: SystemUpdatesManager.hasCommunity && SystemUpdatesManager.communityUpdates.length > 0
        text: SystemUpdatesManager.communityUpdates.length + " " + SystemUpdatesManager.communityLabel + " update"
          + (SystemUpdatesManager.communityUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: SystemUpdatesManager.flatpakUpdates.length > 0
        text: SystemUpdatesManager.flatpakUpdates.length + " Flatpak update"
          + (SystemUpdatesManager.flatpakUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }
    }
  }
}
