import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

SettingsPage {
  id: settingsRoot
  title: "Screen Recording"

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
