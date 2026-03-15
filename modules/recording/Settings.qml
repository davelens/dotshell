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

        FocusTextInput {
          text: RecordingManager.processName
          placeholderText: "e.g. gpu-screen-recorder"
          onEditingFinished: function(value) {
            if (value) RecordingManager.processName = value
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

    // Screenshots directory
    TitleText {
      text: settingsRoot.highlightText("Screenshots Directory", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: screenshotColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: screenshotColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "The directory where screenshots are stored. Used by the file browser panel."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: RecordingManager.screenshotDir
          placeholderText: "e.g. ~/Pictures/screenshots"
          onEditingFinished: function(value) {
            if (value) RecordingManager.screenshotDir = value
          }
        }
      }
    }

    // Screencasts directory
    TitleText {
      text: settingsRoot.highlightText("Screencasts Directory", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: screencastColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: screencastColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "The directory where screencasts are stored. Used by the file browser panel."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: RecordingManager.screencastDir
          placeholderText: "e.g. ~/Videos/screencasts"
          onEditingFinished: function(value) {
            if (value) RecordingManager.screencastDir = value
          }
        }
      }
    }

    // Image previewer
    TitleText {
      text: settingsRoot.highlightText("Image Previewer", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: imagePreviewerColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: imagePreviewerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Command used to preview screenshots from the file browser panel."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: RecordingManager.imagePreviewer
          placeholderText: "sushi"
          onEditingFinished: function(value) {
            if (value) RecordingManager.imagePreviewer = value
          }
        }
      }
    }

    // Video previewer
    TitleText {
      text: settingsRoot.highlightText("Video Previewer", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: videoPreviewerColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: videoPreviewerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Command used to preview screencasts from the file browser panel."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: RecordingManager.videoPreviewer
          placeholderText: "sushi"
          onEditingFinished: function(value) {
            if (value) RecordingManager.videoPreviewer = value
          }
        }
      }
    }
  }
}
