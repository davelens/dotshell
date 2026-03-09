import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../core/components"

DialogOverlay {
  id: switcher
  title: "Switch Profile"

  // Confirmation state for deletion
  property string confirmDeleteDir: ""

  // Confirmation state for reset
  property bool confirmReset: false

  // Reset confirmation when this component is shown
  Component.onCompleted: {
    confirmDeleteDir = ""
    confirmReset = false
  }

  // Profile list
  Column {
    width: parent.width
    spacing: 8

    Text {
      text: "Available profiles"
      color: Theme.textTertiary
      font.pixelSize: 12
      font.bold: true
    }

    Rectangle {
      width: parent.width
      height: profileListColumn.height + 12
      radius: 8
      color: Theme.bgBaseAlt
      border.width: 1
      border.color: Theme.bgBorder

      Column {
        id: profileListColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 4

        Repeater {
          model: GeneralSettings.profiles

      Row {
        id: rowItem
        required property var modelData
        required property int index
        width: parent.width
        spacing: 0

        // Profile row (focusable)
        Rectangle {
          id: profileRow

          width: parent.width - (deleteBtn.visible ? deleteBtn.width : 0)
          height: 44
          radius: 6
          activeFocusOnTab: true
          color: {
            if (rowItem.modelData.dir === GeneralSettings.activeProfile) return Theme.bgCard
            if (activeFocus || profileHover.containsMouse) return Theme.bgCard
            return "transparent"
          }

          // Focus ring
          Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: 8
            color: "transparent"
            border.width: 2
            border.color: Theme.focusRing
            visible: profileRow.activeFocus
          }

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Active indicator
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: Theme.accent
              font.pixelSize: 14
              font.family: "Symbols Nerd Font"
              visible: rowItem.modelData.dir === GeneralSettings.activeProfile
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: rowItem.modelData.name
              color: rowItem.modelData.dir === GeneralSettings.activeProfile ? Theme.textPrimary : Theme.textSecondary
              font.pixelSize: 14
            }
          }

          MouseArea {
            id: profileHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (rowItem.modelData.dir !== GeneralSettings.activeProfile) {
                GeneralSettings.switchProfile(rowItem.modelData.dir)
              }
            }
          }

          Keys.onReturnPressed: {
            if (rowItem.modelData.dir !== GeneralSettings.activeProfile) {
              GeneralSettings.switchProfile(rowItem.modelData.dir)
            }
          }
          Keys.onSpacePressed: {
            if (rowItem.modelData.dir !== GeneralSettings.activeProfile) {
              GeneralSettings.switchProfile(rowItem.modelData.dir)
            }
          }
        }

        // Delete button (not for first profile / not for active profile)
        Item {
          id: deleteBtn
          width: visible ? 44 : 0
          height: 44
          visible: rowItem.index > 0 && rowItem.modelData.dir !== GeneralSettings.activeProfile
          activeFocusOnTab: visible

          // Focus ring
          Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: 16
            color: "transparent"
            border.width: 2
            border.color: Theme.focusRing
            visible: deleteBtn.activeFocus
          }

          Text {
            anchors.centerIn: parent
            text: switcher.confirmDeleteDir === rowItem.modelData.dir ? "?" : "󰩺"
            color: {
              if (switcher.confirmDeleteDir === rowItem.modelData.dir) return Theme.danger
              if (deleteBtn.activeFocus || deleteHover.containsMouse) return Theme.danger
              return Theme.textMuted
            }
            font.pixelSize: switcher.confirmDeleteDir === rowItem.modelData.dir ? 16 : 14
            font.family: switcher.confirmDeleteDir === rowItem.modelData.dir ? undefined : "Symbols Nerd Font"
            font.bold: switcher.confirmDeleteDir === rowItem.modelData.dir
          }

          MouseArea {
            id: deleteHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (switcher.confirmDeleteDir === rowItem.modelData.dir) {
                GeneralSettings.deleteProfile(rowItem.modelData.dir)
                switcher.confirmDeleteDir = ""
              } else {
                switcher.confirmDeleteDir = rowItem.modelData.dir
                confirmTimer.restart()
              }
            }
          }

          Keys.onReturnPressed: deleteHover.clicked(null)
          Keys.onSpacePressed: deleteHover.clicked(null)
        }
        }
      }
    }
  }
  }

  // Reset to defaults button
  FocusButton {
    anchors.left: parent.left
    anchors.right: parent.right
    height: 32
    text: switcher.confirmReset ? "Are you sure?" : "Reset to defaults"
    fontSize: 12
    backgroundColor: Theme.danger
    hoverColor: Qt.darker(Theme.danger, 1.1)
    textColor: Theme.bgDeep
    textHoverColor: Theme.bgDeep
    onClicked: {
      if (switcher.confirmReset) {
        // Confirmed: reset active profile from repo defaults
        resetProc.running = true
      } else {
        // First click: ask for confirmation
        switcher.confirmReset = true
        resetTimer.restart()
      }
    }
  }

  // Reset confirmation after 3 seconds
  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: switcher.confirmDeleteDir = ""
  }

  // Reset button confirmation timer
  Timer {
    id: resetTimer
    interval: 3000
    onTriggered: switcher.confirmReset = false
  }

  // Process to copy repo defaults into active profile
  Process {
    id: resetProc
    command: {
      var cmds = []
      var modules = ModuleRegistry.modules
      for (var i = 0; i < modules.length; i++) {
        var m = modules[i]
        var repoDefaults = m.path + "/defaults.json"
        var stateFile = DataManager.getStatePath(m.id)
        cmds.push("[ -f '" + repoDefaults + "' ] && cp '" + repoDefaults + "' '" + stateFile + "'")
      }
      return ["sh", "-c", cmds.join(" ; ") + " ; true"]
    }
    onExited: {
      switcher.confirmReset = false
    }
  }
}
