import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.core.components

Rectangle {
  id: card

  // Required properties
  property string appName: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property var urgency: NotificationUrgency.Normal
  property bool showCloseButton: true
  property bool compact: false
  property int notificationId: -1
  property var actions: []
  property string image: ""

  // Track hover state
  property bool hovered: hoverHandler.hovered

  // Focusable contract (for compact cards in history panel)
  property bool showFocusRing: compact
  property bool keyboardFocus: false
  property bool focused: activeFocus && showFocusRing && keyboardFocus
  focus: compact
  activeFocusOnTab: compact

  onActiveFocusChanged: {
    if (!activeFocus) keyboardFocus = false
  }

  signal dismissed()
  signal clicked()

  width: parent ? parent.width : 360
  height: compact ? compactLayout.height + 24 : fullLayout.height + 28
  topLeftRadius: 0
  bottomLeftRadius: 0
  topRightRadius: 8
  bottomRightRadius: 8
  color: hovered || focused ? Theme.bgCardHover : Theme.bgDeep
  border.width: focused ? 2 : 2
  border.color: focused ? Theme.focusRing : Theme.bgBorder

  // Copy body text to clipboard
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Y && compact) {
      Quickshell.clipboardText = card.body || card.summary
      event.accepted = true
    }
  }

  // Hover detection without blocking mouse events
  HoverHandler {
    id: hoverHandler
  }

  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Theme.overlay
    shadowHorizontalOffset: 2
    shadowVerticalOffset: 2
    shadowBlur: 0.5
  }

  // Left border for urgency indication
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 3
    color: {
      if (urgency === NotificationUrgency.Critical) return Theme.danger
      if (urgency === NotificationUrgency.Low) return Theme.bgBorder
      return Theme.accent
    }
  }

  // Full layout (for popups)
  Column {
    id: fullLayout
    visible: !compact
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: 26
    anchors.rightMargin: showCloseButton ? 40 : 26
    anchors.topMargin: 12
    spacing: 4

    // Header row: icon + app name
    Row {
      visible: appName !== "General"
      spacing: 8

      // App icon
      IconImage {
        id: iconImage
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 18
        source: appIcon
        visible: appIcon !== ""
      }

      Text {
        visible: appIcon === ""
        text: "󰀄"
        color: Theme.textMuted
        font.pixelSize: 16
        font.family: "Symbols Nerd Font"
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: appName
        color: Theme.textSubtle
        font.pixelSize: 14
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Summary
    Text {
      width: parent.width
      text: summary
      color: Theme.textPrimary
      font.pixelSize: 15
      font.bold: true
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    // Body (selectable)
    TextEdit {
      width: parent.width
      height: Math.min(implicitHeight, 36)  // ~2 lines at 14px
      text: body
      color: Theme.textSecondary
      font.pixelSize: 14
      wrapMode: Text.WordWrap
      readOnly: true
      selectByMouse: true
      selectionColor: Theme.bgBorder
      selectedTextColor: Theme.textPrimary
      visible: body !== ""
      clip: true
    }

    // Image preview
    Image {
      id: previewImage
      visible: previewImage.status === Image.Ready
      source: image || ""
      width: visible ? parent.width : 0
      height: visible ? implicitHeight * (parent.width / Math.max(implicitWidth, 1)) : 0
      fillMode: Image.PreserveAspectFit
      smooth: true
    }

    // Action buttons
    Row {
      visible: actions.length > 0
      spacing: 6
      topPadding: 4

      Repeater {
        model: actions

        Rectangle {
          required property var modelData
          width: actionLabel.implicitWidth + 16
          height: 26
          radius: 4
          color: actionArea.containsMouse ? Theme.bgBorder : Theme.bgCard

          Text {
            id: actionLabel
            anchors.centerIn: parent
            text: modelData.text
            color: Theme.accent
            font.pixelSize: 12
          }

          MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationManager.invokeAction(card.notificationId, modelData.identifier)
          }

          Behavior on color {
            ColorAnimation { duration: 100 }
          }
        }
      }
    }
  }

  // Compact layout (for history panel)
  Column {
    id: compactLayout
    visible: compact
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: 16
    anchors.rightMargin: showCloseButton ? 36 : 16
    anchors.topMargin: 10
    spacing: 2

    // Summary
    Text {
      width: parent.width
      text: summary
      color: Theme.textPrimary
      font.pixelSize: 13
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    // Body (selectable, word-wrapped)
    TextEdit {
      width: parent.width
      text: body
      color: Theme.textSecondary
      font.pixelSize: 12
      wrapMode: Text.WordWrap
      readOnly: true
      selectByMouse: true
      selectionColor: Theme.bgBorder
      selectedTextColor: Theme.textPrimary
      visible: body !== ""
    }
  }

  // Close button (visible on hover or keyboard focus)
  FocusIconButton {
    visible: showCloseButton && (card.hovered || card.focused || focused)
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.top: parent.top
    anchors.topMargin: compact ? 6 : 8
    icon: "󰅖"
    iconSize: 14
    iconColor: Theme.textMuted
    hoverColor: Theme.danger
    onClicked: card.dismissed()
  }

  // Click handler for the card (tap handler doesn't block text selection)
  TapHandler {
    onTapped: card.clicked()
  }

  Behavior on color {
    ColorAnimation { duration: 100 }
  }
}
