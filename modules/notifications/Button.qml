import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  icon: NotificationManager.getIcon()
  iconColor: NotificationManager.isDndActive ? Theme.textMuted : Theme.textPrimary

  onClicked: NotificationManager.togglePanel()

  // Unread badge
  Rectangle {
    id: badge
    visible: NotificationManager.unreadCount > 0 && !NotificationManager.isDndActive
    anchors.right: parent.right
    anchors.rightMargin: -2
    anchors.top: parent.top
    anchors.topMargin: -2
    width: Math.max(badgeText.width + 6, height)
    height: 14
    radius: 7
    color: Theme.danger

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: NotificationManager.unreadCount > 99 ? "99+" : NotificationManager.unreadCount.toString()
      color: Theme.bgDeep
      font.pixelSize: 9
      font.bold: true
    }
  }
}
