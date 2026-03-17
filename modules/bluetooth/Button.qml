import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  popupId: "bluetooth"
  icon: BluetoothManager.getIcon()
  iconColor: BluetoothManager.powered ? Theme.textPrimary : Theme.textMuted
}
