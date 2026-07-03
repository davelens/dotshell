import QtQuick
import QtQuick.Controls
import qs

// Scaffold for a settings page: a scrollable column with an optional title
// and search highlighting. Child items are placed in the internal Column
// below the title via the default property alias.
ScrollView {
  id: page

  anchors.fill: parent
  clip: true
  contentWidth: availableWidth

  // Search query passed from SettingsPanel
  property string searchQuery: ""

  // Page title; leave empty when the page renders its own header
  property string title: ""

  property alias contentSpacing: column.spacing
  default property alias content: column.data

  // Highlight matching text with yellow background
  function highlightText(text, query) {
    return Theme.highlightText(text, query)
  }

  Column {
    id: column
    width: parent.width
    spacing: 20

    Text {
      visible: page.title !== ""
      text: page.title
      color: Theme.textPrimary
      font.pixelSize: 24
      font.bold: true
    }
  }
}
