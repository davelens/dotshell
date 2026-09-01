import QtQuick
import qs

Rectangle {
  id: root

  property var tabs: []
  property string activeTab: ""
  property string searchPlaceholder: ""
  property bool searchVisible: true
  property Component searchAccessory: null
  property bool searchAccessoryVisible: false
  property alias searchText: searchInput.text
  readonly property bool searchActive: searchInput.activeFocus

  default property alias content: contentArea.data

  signal tabSelected(string tabId)
  signal searchAccepted(string text)
  signal searchDismissed()

  function focusSearch() {
    searchInput.forceActiveFocus()
  }

  function blurSearch() {
    searchInput.focus = false
  }

  function clearSearch() {
    searchInput.text = ""
  }

  anchors.centerIn: parent
  color: Theme.bgBase
  radius: 8
  border.width: 1
  border.color: Theme.bgBorder

  MouseArea {
    anchors.fill: parent
    onClicked: function(event) { event.accepted = true }
  }

  Column {
    id: panelColumn
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    Row {
      id: tabBar
      width: parent.width
      spacing: 0

      Repeater {
        id: tabRepeater
        model: root.tabs

        Rectangle {
          required property var modelData
          required property int index

          width: tabBar.width / tabRepeater.count
          height: 40
          color: root.activeTab === modelData.id ? Theme.bgCard : "transparent"
          radius: 6

          Text {
            anchors.centerIn: parent
            text: modelData.label
            color: root.activeTab === modelData.id ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.scaledFontSize(15)
            font.bold: root.activeTab === modelData.id
          }

          Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.6
            height: 3
            radius: 1.5
            color: Theme.accent
            visible: root.activeTab === modelData.id
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tabSelected(modelData.id)
          }
        }
      }
    }

    Row {
      id: searchRow
      width: parent.width
      height: 36
      spacing: 8
      visible: root.searchVisible
      z: 1

      Rectangle {
        id: searchBar
        width: parent.width - (accessoryLoader.visible ? accessoryLoader.width + parent.spacing : 0)
        height: parent.height
        radius: 6
        color: Theme.bgCardHover
        border.width: searchInput.activeFocus ? 2 : 1
        border.color: searchInput.activeFocus ? Theme.focusRing : Theme.bgBorder

        Text {
          id: searchIcon
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "󰍉"
          font.family: "Symbols Nerd Font"
          font.pixelSize: Theme.scaledFontSize(14)
          color: Theme.textMuted
        }

        TextInput {
          id: searchInput
          anchors.left: searchIcon.right
          anchors.leftMargin: 8
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          height: parent.height
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: Theme.scaledFontSize(14)
          verticalAlignment: TextInput.AlignVCenter
          activeFocusOnTab: true
          selectByMouse: true
          clip: true

          property bool showFocusRing: false

          Text {
            anchors.fill: parent
            anchors.verticalCenter: parent.verticalCenter
            text: root.searchPlaceholder
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.scaledFontSize(14)
            verticalAlignment: Text.AlignVCenter
            visible: !searchInput.text && !searchInput.activeFocus
          }

          Keys.onReturnPressed: root.searchAccepted(text)
          Keys.onEscapePressed: {
            root.clearSearch()
            root.blurSearch()
            root.searchDismissed()
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          onPressed: function(mouse) {
            root.focusSearch()
            mouse.accepted = false
          }
        }
      }

      Loader {
        id: accessoryLoader
        visible: root.searchAccessoryVisible && root.searchAccessory !== null
        sourceComponent: root.searchAccessory
      }
    }

    Item {
      id: contentArea
      width: parent.width
      height: parent.height - tabBar.height
        - (searchRow.visible ? searchRow.height + panelColumn.spacing : 0)
        - panelColumn.spacing
    }
  }
}
