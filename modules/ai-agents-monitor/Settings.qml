import QtQuick
import qs
import qs.core.components

SettingsPage {
  id: settingsRoot
  title: "AI Agents Monitor"

  // Remote monitor section
  TitleText {
    text: settingsRoot.highlightText("Remote Monitor", settingsRoot.searchQuery)
    textFormat: Text.RichText
  }

  Rectangle {
    width: parent.width
    height: remoteColumn.height + 24
    radius: 8
    color: Theme.bgCard

    Column {
      id: remoteColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 12
      spacing: 12

      HelpText {
        width: parent.width
        text: "SSH host alias of another dotshell machine whose AI agent "
          + "sessions should appear here. Authentication, port, and any "
          + "Tailscale routing come from your <b>~/.ssh/config</b>. Leave "
          + "empty to only monitor this machine."
        textFormat: Text.RichText
        wrapMode: Text.WordWrap
      }

      FocusTextInput {
        width: parent.width
        text: AiAgentsMonitorManager.remoteHost
        placeholderText: "e.g. devserver"
        onEditingFinished: function(value) {
          AiAgentsMonitorManager.remoteHost = value.trim()
        }
      }
    }
  }
}
