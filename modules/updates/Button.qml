import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  property bool showInBar: UpdatesManager.totalCount > 0

  icon: UpdatesManager.getIcon()
  iconColor: Theme.success

  TooltipBase {
    anchorItem: button
    visible: button.hovered && !button.popupManager.isOpen(button.popupId) && button.visible

    Column {
      spacing: 2

      Text {
        visible: UpdatesManager.checking || UpdatesManager.totalCount === 0
        text: UpdatesManager.checking ? "Checking for updates..." : "System up to date"
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: UpdatesManager.repoUpdates.length > 0
        text: UpdatesManager.repoUpdates.length + " " + UpdatesManager.repoLabel + " update"
          + (UpdatesManager.repoUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: UpdatesManager.hasCommunity && UpdatesManager.communityUpdates.length > 0
        text: UpdatesManager.communityUpdates.length + " " + UpdatesManager.communityLabel + " update"
          + (UpdatesManager.communityUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: UpdatesManager.flatpakUpdates.length > 0
        text: UpdatesManager.flatpakUpdates.length + " Flatpak update"
          + (UpdatesManager.flatpakUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }
    }
  }
}
