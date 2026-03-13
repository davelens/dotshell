import QtQuick
import QtQuick.Controls
import "../.."
import "../../core/components"

ScrollView {
  id: settingsRoot
  anchors.fill: parent
  clip: true
  contentWidth: availableWidth

  // Search query passed from settings panel
  property string searchQuery: ""

  // Highlight matching text with yellow background
  function highlightText(text, query) {
    if (!query) return text
    var lowerText = text.toLowerCase()
    var lowerQuery = query.toLowerCase()
    var idx = lowerText.indexOf(lowerQuery)
    if (idx === -1) return text
    var before = text.substring(0, idx)
    var match = text.substring(idx, idx + query.length)
    var after = text.substring(idx + query.length)
    return before + '<span style="background-color: ' + Theme.warning + '; color: ' + Theme.bgDeep + ';">' + match + '</span>' + after
  }

  Column {
    width: parent.width
    spacing: 20

    Text {
      text: "Power Menu"
      color: Theme.textPrimary
      font.pixelSize: 24
      font.bold: true
    }

    // -- Commands section ---------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Commands", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: commandsColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: commandsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 16

        HelpText {
          width: parent.width
          text: "Shell commands executed for each power action. Changes take effect immediately."
          wrapMode: Text.WordWrap
        }

        // Lock command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Lock"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          Rectangle {
            width: parent.width
            height: 36
            radius: 6
            color: Theme.bgCardHover
            border.width: lockInput.activeFocus ? 2 : 1
            border.color: lockInput.activeFocus ? Theme.focusRing : Theme.bgBorder

            TextInput {
              id: lockInput
              anchors.fill: parent
              anchors.margins: 8
              color: Theme.textPrimary
              font.pixelSize: 14
              verticalAlignment: TextInput.AlignVCenter
              activeFocusOnTab: true
              selectByMouse: true
              text: PowerManager.lockCommand

              property bool showFocusRing: false

              Text {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                text: "loginctl lock-session"
                color: Theme.textMuted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                visible: !lockInput.text && !lockInput.activeFocus
              }

              onEditingFinished: {
                if (text) PowerManager.lockCommand = text
              }

              Keys.onReturnPressed: focus = false
              Keys.onEnterPressed: focus = false
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                lockInput.forceActiveFocus()
                mouse.accepted = false
              }
            }
          }
        }

        // Suspend command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Suspend"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          Rectangle {
            width: parent.width
            height: 36
            radius: 6
            color: Theme.bgCardHover
            border.width: suspendInput.activeFocus ? 2 : 1
            border.color: suspendInput.activeFocus ? Theme.focusRing : Theme.bgBorder

            TextInput {
              id: suspendInput
              anchors.fill: parent
              anchors.margins: 8
              color: Theme.textPrimary
              font.pixelSize: 14
              verticalAlignment: TextInput.AlignVCenter
              activeFocusOnTab: true
              selectByMouse: true
              text: PowerManager.suspendCommand

              property bool showFocusRing: false

              Text {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                text: "systemctl suspend"
                color: Theme.textMuted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                visible: !suspendInput.text && !suspendInput.activeFocus
              }

              onEditingFinished: {
                if (text) PowerManager.suspendCommand = text
              }

              Keys.onReturnPressed: focus = false
              Keys.onEnterPressed: focus = false
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                suspendInput.forceActiveFocus()
                mouse.accepted = false
              }
            }
          }
        }

        // Logout command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Logout"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          Rectangle {
            width: parent.width
            height: 36
            radius: 6
            color: Theme.bgCardHover
            border.width: logoutInput.activeFocus ? 2 : 1
            border.color: logoutInput.activeFocus ? Theme.focusRing : Theme.bgBorder

            TextInput {
              id: logoutInput
              anchors.fill: parent
              anchors.margins: 8
              color: Theme.textPrimary
              font.pixelSize: 14
              verticalAlignment: TextInput.AlignVCenter
              activeFocusOnTab: true
              selectByMouse: true
              text: PowerManager.logoutCommand

              property bool showFocusRing: false

              Text {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                text: "swaymsg exit"
                color: Theme.textMuted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                visible: !logoutInput.text && !logoutInput.activeFocus
              }

              onEditingFinished: {
                if (text) PowerManager.logoutCommand = text
              }

              Keys.onReturnPressed: focus = false
              Keys.onEnterPressed: focus = false
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                logoutInput.forceActiveFocus()
                mouse.accepted = false
              }
            }
          }
        }

        // Reboot command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Reboot"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          Rectangle {
            width: parent.width
            height: 36
            radius: 6
            color: Theme.bgCardHover
            border.width: rebootInput.activeFocus ? 2 : 1
            border.color: rebootInput.activeFocus ? Theme.focusRing : Theme.bgBorder

            TextInput {
              id: rebootInput
              anchors.fill: parent
              anchors.margins: 8
              color: Theme.textPrimary
              font.pixelSize: 14
              verticalAlignment: TextInput.AlignVCenter
              activeFocusOnTab: true
              selectByMouse: true
              text: PowerManager.rebootCommand

              property bool showFocusRing: false

              Text {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                text: "systemctl reboot"
                color: Theme.textMuted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                visible: !rebootInput.text && !rebootInput.activeFocus
              }

              onEditingFinished: {
                if (text) PowerManager.rebootCommand = text
              }

              Keys.onReturnPressed: focus = false
              Keys.onEnterPressed: focus = false
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                rebootInput.forceActiveFocus()
                mouse.accepted = false
              }
            }
          }
        }

        // Shutdown command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Shutdown"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          Rectangle {
            width: parent.width
            height: 36
            radius: 6
            color: Theme.bgCardHover
            border.width: shutdownInput.activeFocus ? 2 : 1
            border.color: shutdownInput.activeFocus ? Theme.focusRing : Theme.bgBorder

            TextInput {
              id: shutdownInput
              anchors.fill: parent
              anchors.margins: 8
              color: Theme.textPrimary
              font.pixelSize: 14
              verticalAlignment: TextInput.AlignVCenter
              activeFocusOnTab: true
              selectByMouse: true
              text: PowerManager.shutdownCommand

              property bool showFocusRing: false

              Text {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                text: "systemctl poweroff"
                color: Theme.textMuted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                visible: !shutdownInput.text && !shutdownInput.activeFocus
              }

              onEditingFinished: {
                if (text) PowerManager.shutdownCommand = text
              }

              Keys.onReturnPressed: focus = false
              Keys.onEnterPressed: focus = false
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                shutdownInput.forceActiveFocus()
                mouse.accepted = false
              }
            }
          }
        }
      }
    }
  }
}
