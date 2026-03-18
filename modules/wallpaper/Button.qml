import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  icon: "󰸉"
  iconColor: Theme.textPrimary

  onClicked: {
    WallpaperManager.togglePanel()
  }
}
