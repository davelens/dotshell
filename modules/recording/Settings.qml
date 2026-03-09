import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../.."
import "../../core/components"

ScrollView {
  id: settingsRoot
  anchors.fill: parent
  clip: true
  contentWidth: availableWidth

  // Search query passed from SettingsPanel
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
      text: "Screen Recording"
      color: Theme.textPrimary
      font.pixelSize: 24
      font.bold: true
    }

    // Process name
    TitleText {
      text: settingsRoot.highlightText("Recording Process", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: processColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: processColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "The process name used to detect and stop screen recording."
          wrapMode: Text.WordWrap
        }

        // Text input for process name
        Rectangle {
          width: parent.width
          height: 36
          radius: 6
          color: Theme.bgCardHover
          border.width: processInput.activeFocus ? 2 : 1
          border.color: processInput.activeFocus ? Theme.focusRing : Theme.bgBorder

          TextInput {
            id: processInput
            anchors.fill: parent
            anchors.margins: 8
            color: Theme.textPrimary
            font.pixelSize: 14
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnTab: true
            selectByMouse: true
            text: RecordingManager.processName

            property bool showFocusRing: false

            Text {
              anchors.fill: parent
              anchors.verticalCenter: parent.verticalCenter
              text: "e.g. gpu-screen-recorder"
              color: Theme.textMuted
              font.pixelSize: 14
              verticalAlignment: Text.AlignVCenter
              visible: !processInput.text && !processInput.activeFocus
            }

            onEditingFinished: {
              if (text) {
                RecordingManager.processName = text
              }
            }

            Keys.onReturnPressed: focus = false
            Keys.onEnterPressed: focus = false
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: function(mouse) {
              processInput.forceActiveFocus()
              mouse.accepted = false
            }
          }
        }

        HelpText {
          width: parent.width
          text: "This is both the process name checked by <b>pidof</b> to detect active recording, and the target for <b>pkill -SIGINT</b> when stopping."
          textFormat: Text.RichText
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
