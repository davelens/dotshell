import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

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
      text: "Wallpaper"
      color: Theme.textPrimary
      font.pixelSize: 24
      font.bold: true
    }

    // -- Wallpaper directory ------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Wallpaper Directory", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: dirColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: dirColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Directory where wallpapers are stored and downloaded to."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: WallpaperManager.wallpaperDir
          placeholderText: "~/Pictures/wallpapers"
          onEditingFinished: function(value) {
            if (value) WallpaperManager.wallpaperDir = value
          }
        }
      }
    }

    // -- API key ------------------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Wallhaven API Key", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: apiColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: apiColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Optional. Provides access to NSFW content and your collections. Get your key from wallhaven.cc account settings."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: WallpaperManager.apiKey
          placeholderText: "Leave empty for SFW-only browsing"
          onEditingFinished: function(value) {
            WallpaperManager.apiKey = value || ""
          }
        }
      }
    }

    // -- Default categories -------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Default Categories", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: catColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: catColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Which wallhaven categories to include in search results. A 3-digit string where each position is 1 (on) or 0 (off): General, Anime, People."
          wrapMode: Text.WordWrap
        }

        Row {
          spacing: 16

          Row {
            spacing: 6
            SwitchToggle {
              checked: WallpaperManager.defaultCategories.charAt(0) === "1"
              onClicked: {
                var cats = WallpaperManager.defaultCategories.split("")
                cats[0] = checked ? "0" : "1"
                WallpaperManager.defaultCategories = cats.join("")
              }
            }
            Text {
              text: "General"
              color: Theme.textPrimary
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            spacing: 6
            SwitchToggle {
              checked: WallpaperManager.defaultCategories.charAt(1) === "1"
              onClicked: {
                var cats = WallpaperManager.defaultCategories.split("")
                cats[1] = checked ? "0" : "1"
                WallpaperManager.defaultCategories = cats.join("")
              }
            }
            Text {
              text: "Anime"
              color: Theme.textPrimary
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            spacing: 6
            SwitchToggle {
              checked: WallpaperManager.defaultCategories.charAt(2) === "1"
              onClicked: {
                var cats = WallpaperManager.defaultCategories.split("")
                cats[2] = checked ? "0" : "1"
                WallpaperManager.defaultCategories = cats.join("")
              }
            }
            Text {
              text: "People"
              color: Theme.textPrimary
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }

    // -- Purity -------------------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Content Purity", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: purityColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: purityColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Content filter. NSFW requires a valid API key. A 3-digit string: SFW, Sketchy, NSFW."
          wrapMode: Text.WordWrap
        }

        Row {
          spacing: 16

          Row {
            spacing: 6
            SwitchToggle {
              checked: WallpaperManager.defaultPurity.charAt(0) === "1"
              onClicked: {
                var p = WallpaperManager.defaultPurity.split("")
                p[0] = checked ? "0" : "1"
                WallpaperManager.defaultPurity = p.join("")
              }
            }
            Text {
              text: "SFW"
              color: Theme.textPrimary
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            spacing: 6
            SwitchToggle {
              checked: WallpaperManager.defaultPurity.charAt(1) === "1"
              onClicked: {
                var p = WallpaperManager.defaultPurity.split("")
                p[1] = checked ? "0" : "1"
                WallpaperManager.defaultPurity = p.join("")
              }
            }
            Text {
              text: "Sketchy"
              color: Theme.textPrimary
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            spacing: 6
            SwitchToggle {
              checked: WallpaperManager.defaultPurity.charAt(2) === "1"
              onClicked: {
                var p = WallpaperManager.defaultPurity.split("")
                p[2] = checked ? "0" : "1"
                WallpaperManager.defaultPurity = p.join("")
              }
            }
            Text {
              text: "NSFW"
              color: Theme.textPrimary
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }

    // -- Minimum resolution -------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Minimum Resolution", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: resColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: resColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        HelpText {
          width: parent.width
          text: "Only show wallpapers at or above this resolution."
          wrapMode: Text.WordWrap
        }

        FocusTextInput {
          text: WallpaperManager.minResolution
          placeholderText: "e.g. 1920x1080"
          onEditingFinished: function(value) {
            WallpaperManager.minResolution = value || ""
          }
        }
      }
    }
  }
}
