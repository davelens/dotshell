import QtQuick
import "../.."

// Password input field with visibility toggle and submit button.
// Emits submitted(password) on Enter or submit button click, and
// cancelled() on Escape.
//
// Usage:
//   PasswordInput {
//     onSubmitted: function(password) { SomeManager.connect(ssid, password) }
//     onCancelled: SomeManager.cancelPending()
//   }
Item {
  id: root

  property string placeholderText: "Enter password"

  // Expose the current text for external reads (e.g. parent visibility checks)
  readonly property alias text: passwordField.text

  signal submitted(string password)
  signal cancelled()

  // Clear the field and reset echo mode (call when re-showing)
  function clear() {
    passwordField.text = ""
    passwordField.echoMode = TextInput.Password
  }

  // Focus the input field
  function focusInput() {
    passwordField.forceActiveFocus()
  }

  width: parent ? parent.width : 200
  height: 36

  Rectangle {
    anchors.fill: parent
    radius: 4
    color: Theme.bgCard
    border.width: 1
    border.color: passwordField.activeFocus ? Theme.accent : Theme.bgCardHover

    Row {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 4
      spacing: 4

      TextInput {
        id: passwordField
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - toggleVisibility.width - submitBtn.width - 12
        color: Theme.textPrimary
        font.pixelSize: 14
        clip: true
        echoMode: TextInput.Password

        Text {
          anchors.fill: parent
          anchors.verticalCenter: parent.verticalCenter
          text: root.placeholderText
          color: Theme.textMuted
          font.pixelSize: 14
          visible: !passwordField.text
        }

        Keys.onReturnPressed: {
          if (passwordField.text) root.submitted(passwordField.text)
        }
        Keys.onEnterPressed: {
          if (passwordField.text) root.submitted(passwordField.text)
        }
        Keys.onEscapePressed: root.cancelled()
      }

      // Show/hide password toggle
      Text {
        id: toggleVisibility
        anchors.verticalCenter: parent.verticalCenter
        text: passwordField.echoMode === TextInput.Password ? "󰈈" : "󰈉"
        color: toggleMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
        font.pixelSize: 16
        font.family: "Symbols Nerd Font"
        width: 28
        horizontalAlignment: Text.AlignHCenter

        MouseArea {
          id: toggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            passwordField.echoMode = passwordField.echoMode === TextInput.Password
              ? TextInput.Normal
              : TextInput.Password
          }
        }
      }

      // Submit button
      Rectangle {
        id: submitBtn
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 4
        color: submitMouse.containsMouse && passwordField.text
          ? Theme.accent : "transparent"

        Text {
          anchors.centerIn: parent
          text: "󰁔"
          color: passwordField.text
            ? (submitMouse.containsMouse ? Theme.bgBase : Theme.accent)
            : Theme.bgBorder
          font.pixelSize: 16
          font.family: "Symbols Nerd Font"
        }

        MouseArea {
          id: submitMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: passwordField.text ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (passwordField.text) root.submitted(passwordField.text)
          }
        }
      }
    }
  }
}
