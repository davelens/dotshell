import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

Column {
  id: sourceColumn

  required property string sourceId
  required property string label
  required property var updates
  required property real columnWidth
  required property int maxVisibleItems
  required property int rowHeight
  required property int rowSpacing

  width: columnWidth
  spacing: 8

  TitleText {
    text: sourceColumn.label + " (" + sourceColumn.updates.length + ")"
  }

  FocusButton {
    width: parent.width
    height: 26
    text: "Update all"
    fontSize: 12
    backgroundColor: sourceColumn.updates.length > 0 && !UpdatesManager.blocked ? Theme.bgCardHover : Theme.bgBaseAlt
    textColor: sourceColumn.updates.length > 0 && !UpdatesManager.blocked ? Theme.textPrimary : Theme.textMuted
    hoverColor: Theme.bgBorder
    enabled: sourceColumn.updates.length > 0 && !UpdatesManager.blocked
    opacity: enabled ? 1.0 : 0.4
    onClicked: UpdatesManager.updateSource(sourceColumn.sourceId)
  }

  ScrollView {
    width: parent.width
    clip: true
    contentWidth: availableWidth
    height: {
      var count = Math.min(sourceColumn.updates.length, sourceColumn.maxVisibleItems)
      if (count === 0) return 28
      return count * sourceColumn.rowHeight + (count - 1) * sourceColumn.rowSpacing
    }

    Column {
      width: parent.width
      spacing: sourceColumn.rowSpacing

      Repeater {
        model: sourceColumn.updates

        Rectangle {
          id: packageRow
          required property var modelData
          readonly property string packageKey: sourceColumn.sourceId === "flatpak" ? modelData.appId : modelData.name
          readonly property bool updating: UpdatesManager.isUpdating(packageKey)

          width: parent.width
          height: sourceColumn.rowHeight
          radius: 4
          color: updating ? Theme.bgBaseAlt : (packageMouse.containsMouse ? Theme.bgCard : "transparent")

          Column {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: downloadIcon.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              width: parent.width
              text: packageRow.modelData.name
              color: packageRow.updating ? Theme.textMuted : Theme.textPrimary
              font.pixelSize: 13
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: sourceColumn.sourceId === "flatpak"
                ? (packageRow.modelData.newVersion || packageRow.modelData.appId)
                : packageRow.modelData.currentVersion + " → " + packageRow.modelData.newVersion
              color: packageRow.updating ? Theme.textSubtle : Theme.textMuted
              font.pixelSize: 10
              elide: Text.ElideMiddle
            }
          }

          Text {
            id: downloadIcon
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: packageRow.updating ? "󰔿" : "󰇚"
            color: {
              if (UpdatesManager.blocked) return Theme.bgBorder
              if (packageRow.updating) return Theme.textMuted
              return packageMouse.containsMouse ? Theme.success : Theme.textMuted
            }
            font.pixelSize: 13
            font.family: "Symbols Nerd Font"

            RotationAnimation on rotation {
              running: packageRow.updating
              from: 0
              to: 360
              duration: 1000
              loops: Animation.Infinite
            }
          }

          MouseArea {
            id: packageMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: UpdatesManager.blocked || packageRow.updating ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            onClicked: {
              if (!UpdatesManager.blocked && !packageRow.updating) {
                UpdatesManager.updatePackage(packageRow.packageKey, sourceColumn.sourceId)
              }
            }
          }
        }
      }

      Text {
        visible: sourceColumn.updates.length === 0
        text: "No updates"
        color: Theme.textMuted
        font.pixelSize: 12
        topPadding: 4
      }
    }
  }
}
