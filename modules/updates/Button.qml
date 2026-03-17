import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  // Whether this button should be shown in the bar (checked by shell.qml delegate)
  property bool showInBar: UpdatesManager.totalCount > 0

  popupId: "updates"

  icon: UpdatesManager.getIcon()
  iconColor: Theme.success

  // Hover tooltip showing update count breakdown
  TooltipBase {
    anchorItem: button
    visible: button.hovered && !button.popupManager.isOpen("updates") && button.visible

    Column {
      spacing: 2

      // Single line for checking / up to date states
      Text {
        visible: UpdatesManager.checking || UpdatesManager.totalCount === 0
        text: UpdatesManager.checking ? "Checking for updates..." : "System up to date"
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      // Breakdown lines when updates are available
      Text {
        visible: UpdatesManager.pacmanUpdates.length > 0
        text: UpdatesManager.pacmanUpdates.length + " system update" + (UpdatesManager.pacmanUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: UpdatesManager.aurUpdates.length > 0
        text: UpdatesManager.aurUpdates.length + " package update" + (UpdatesManager.aurUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }

      Text {
        visible: UpdatesManager.flatpakUpdates.length > 0
        text: UpdatesManager.flatpakUpdates.length + " flatpak update" + (UpdatesManager.flatpakUpdates.length !== 1 ? "s" : "")
        color: Theme.textPrimary
        font.pixelSize: 13
      }
    }
  }
}
