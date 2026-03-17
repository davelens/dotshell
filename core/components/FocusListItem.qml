import QtQuick
import qs

Item {
  id: item

  property string icon: ""
  property string text: ""
  property string subtitle: ""  // Optional subtitle below main text
  property string rightIcon: ""
  property int iconSize: 16
  property int fontSize: 14
  property int subtitleFontSize: 11
  property color iconColor: Theme.textMuted
  property color subtitleColor: Theme.textMuted

  // Configurable dimensions and colors (defaults match settings panel usage)
  property int itemHeight: -1  // -1 = auto (56 with subtitle, 48 without)
  property color rightIconColor: Theme.textMuted
  property color rightIconHoverColor: rightIconColor
  property color backgroundColor: "transparent"
  property color hoverBackgroundColor: Theme.bgCard
  property int bodyMargins: 4
  property int bodyRadius: 6

  // Allow parent to control whether focus ring is shown
  property bool showFocusRing: true

  // Track if focus came from keyboard (not mouse)
  property bool keyboardFocus: false

  // Focus support - only show ring for keyboard focus
  property bool focused: activeFocus && showFocusRing && keyboardFocus
  property bool hovered: mouseArea.containsMouse
  focus: true
  activeFocusOnTab: true

  onActiveFocusChanged: {
    if (!activeFocus) keyboardFocus = false
  }

  signal clicked()

  width: parent ? parent.width : 200
  height: itemHeight > 0 ? itemHeight : (subtitle ? 56 : 48)

  // Focus ring (outer when bodyMargins > 0, inset when 0)
  Rectangle {
    anchors.fill: body
    anchors.margins: -3
    radius: body.radius + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.focusRing
    visible: item.focused && item.bodyMargins > 0
  }

  Rectangle {
    id: body
    anchors.fill: parent
    anchors.leftMargin: item.bodyMargins
    anchors.rightMargin: item.bodyMargins
    radius: item.bodyRadius
    color: item.hovered || item.focused ? item.hoverBackgroundColor : item.backgroundColor
    border.width: item.focused && item.bodyMargins === 0 ? 2 : 0
    border.color: Theme.focusRing

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: item.icon
        color: item.iconColor
        font.pixelSize: item.iconSize
        font.family: "Symbols Nerd Font"
        visible: item.icon !== ""
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: item.subtitle ? 2 : 0

        Text {
          text: item.text
          color: Theme.textPrimary
          font.pixelSize: item.fontSize
        }

        Text {
          text: item.subtitle
          color: item.subtitleColor
          font.pixelSize: item.subtitleFontSize
          visible: item.subtitle !== ""
        }
      }
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: item.rightIcon
      color: item.hovered || item.focused ? item.rightIconHoverColor : item.rightIconColor
      font.pixelSize: item.iconSize
      font.family: "Symbols Nerd Font"
      visible: item.rightIcon !== ""
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      item.forceActiveFocus()
      item.clicked()
    }
  }

  Keys.onSpacePressed: item.clicked()
  Keys.onReturnPressed: item.clicked()
  Keys.onEnterPressed: item.clicked()
}
