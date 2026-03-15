import QtQuick
import "../.."

// Reusable styled text input with focus ring, placeholder, and themed
// border highlight. Follows the Focus* component contract so it
// participates in Ctrl+N/P focus cycling.
//
// Usage:
//   FocusTextInput {
//     text: SomeManager.value
//     placeholderText: "e.g. something"
//     onEditingFinished: function(value) { SomeManager.value = value }
//   }
Item {
  id: input

  property alias text: textField.text
  property string placeholderText: ""

  // Focus* contract: discoverable by findFocusables()
  property bool showFocusRing: false
  activeFocusOnTab: true

  // Forward active focus to the inner TextInput so Ctrl+N/P
  // cycling and mouse clicks both land in the editable field.
  onActiveFocusChanged: {
    if (activeFocus) textField.forceActiveFocus()
  }

  signal editingFinished(string text)

  width: parent ? parent.width : 200
  height: 36

  Rectangle {
    id: body
    anchors.fill: parent
    radius: 6
    color: Theme.bgCardHover
    border.width: textField.activeFocus ? 2 : 1
    border.color: textField.activeFocus ? Theme.focusRing : Theme.bgBorder

    TextInput {
      id: textField
      anchors.fill: parent
      anchors.margins: 8
      color: Theme.textPrimary
      font.pixelSize: 14
      verticalAlignment: TextInput.AlignVCenter
      selectByMouse: true

      Text {
        anchors.fill: parent
        anchors.verticalCenter: parent.verticalCenter
        text: input.placeholderText
        color: Theme.textMuted
        font.pixelSize: 14
        verticalAlignment: Text.AlignVCenter
        visible: input.placeholderText && !textField.text && !textField.activeFocus
      }

      onEditingFinished: input.editingFinished(textField.text)

      Keys.onReturnPressed: focus = false
      Keys.onEnterPressed: focus = false
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.IBeamCursor
      onPressed: function(mouse) {
        textField.forceActiveFocus()
        mouse.accepted = false
      }
    }
  }
}
