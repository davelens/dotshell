import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls
import "../.."
import "../../core/components"

// Notification history panel - slides in from right
Variants {
  model: ScreenManager.primaryScreen ? [ScreenManager.primaryScreen] : []

  PanelWindow {
    required property var modelData

    id: panel
    screen: modelData

    // Always visible so the Wayland surface stays mapped and the QML tree
    // stays laid out, avoiding a first-frame hitch when the panel slides in.
    // The panel content sits offscreen (rightMargin: -380) when closed.
    visible: true

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    // Leave room for status bar at top
    margins.top: 32

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "quickshell-notification-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NotificationManager.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Keyboard focus cycling state
    property var focusables: []
    property int focusIndex: -1

    // Recursively find visible, enabled items with showFocusRing
    function findFocusables(item, result) {
      if (!item || !item.visible) return
      if (item.showFocusRing !== undefined && item.enabled !== false) {
        result.push(item)
      }
      if (item.children) {
        for (var i = 0; i < item.children.length; i++) {
          findFocusables(item.children[i], result)
        }
      }
      if (item.contentItem) {
        findFocusables(item.contentItem, result)
      }
    }

    function refreshFocusables() {
      focusables = []
      findFocusables(panelColumn, focusables)
    }

    function findFlickable(item) {
      var p = item ? item.parent : null
      while (p) {
        if (p.contentY !== undefined && p.contentHeight !== undefined && p.height !== undefined)
          return p
        p = p.parent
      }
      return null
    }

    function scrollToItem(item) {
      if (!item) return
      var flickable = findFlickable(item)
      if (!flickable) return
      var mapped = item.mapToItem(flickable.contentItem, 0, 0)
      var itemTop = mapped.y
      var itemBottom = itemTop + item.height
      var visibleTop = flickable.contentY
      var visibleBottom = visibleTop + flickable.height
      var padding = 24
      if (itemTop - padding < visibleTop)
        flickable.contentY = Math.max(0, itemTop - padding)
      else if (itemBottom + padding > visibleBottom)
        flickable.contentY = Math.min(flickable.contentHeight - flickable.height, itemBottom + padding - flickable.height)
    }

    function focusItem(item) {
      if (!item) return
      if (item.keyboardFocus !== undefined) item.keyboardFocus = true
      if (item.showFocusRing !== undefined) item.showFocusRing = true
      if (item.forceActiveFocus) item.forceActiveFocus()
      scrollToItem(item)
    }

    function focusNext() {
      refreshFocusables()
      if (focusables.length === 0) return
      focusIndex = (focusIndex + 1) % focusables.length
      focusItem(focusables[focusIndex])
    }

    function focusPrevious() {
      refreshFocusables()
      if (focusables.length === 0) return
      if (focusIndex < 0) focusIndex = focusables.length - 1
      else focusIndex = (focusIndex - 1 + focusables.length) % focusables.length
      focusItem(focusables[focusIndex])
    }

    function resetFocus() {
      for (var i = 0; i < focusables.length; i++) {
        if (focusables[i].keyboardFocus !== undefined)
          focusables[i].keyboardFocus = false
      }
      focusIndex = -1
      focusables = []
    }

    contentItem {
      focus: NotificationManager.panelOpen
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q
            || (event.key === Qt.Key_BracketLeft && (event.modifiers & Qt.ControlModifier))) {
          panel.resetFocus()
          NotificationManager.closePanel()
          event.accepted = true
        } else if (event.key === Qt.Key_C && !(event.modifiers & Qt.ControlModifier)) {
          NotificationManager.clearHistory()
          event.accepted = true
        } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
          panel.focusNext()
          event.accepted = true
        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
          panel.focusPrevious()
          event.accepted = true
        }
      }
    }

    // Click-outside overlay (only active when panel is open)
    MouseArea {
      anchors.fill: parent
      enabled: NotificationManager.panelOpen
      onClicked: NotificationManager.closePanel()
    }

    // Panel content with slide animation
    // Extends 2px beyond window edges (top, right, bottom) so the compositor
    // clips those edges instead of rendering a visible seam at fractional scaling.
    Rectangle {
      id: panelContent
      anchors.top: parent.top
      anchors.topMargin: -2
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -2
      anchors.right: parent.right
      anchors.rightMargin: NotificationManager.panelOpen ? -2 : -(width + 1)
      width: 382
      color: Theme.bgBase

      Behavior on anchors.rightMargin {
        NumberAnimation {
          id: slideAnimation
          duration: 250
          easing.type: Easing.OutCubic
        }
      }

      border.width: 1
      border.color: Theme.bgBorder

      Column {
        id: panelColumn
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.topMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 18
        spacing: 16

        // Header
        Item {
          width: parent.width
          height: 32

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.textPrimary
            font.pixelSize: 20
            font.bold: true
          }

          FocusIconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰅖"
            iconSize: 18
            hoverColor: Theme.danger
            onClicked: NotificationManager.closePanel()
          }
        }

        // DND toggle section
        Rectangle {
          width: parent.width
          height: dndColumn.height + 24
          radius: 8
          color: Theme.bgCard

          Column {
            id: dndColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Item {
              width: parent.width
              height: 40

              Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // DND toggle switch
                SwitchToggle {
                  id: dndToggle
                  anchors.verticalCenter: parent.verticalCenter
                  checked: NotificationManager.dndEnabled
                  onClicked: NotificationManager.toggleDnd()
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 2

                  Text {
                    text: "Do Not Disturb"
                    color: Theme.textPrimary
                    font.pixelSize: 14
                  }

                  Text {
                    text: NotificationManager.isDndActive
                      ? (NotificationManager.dndEnabled ? "Enabled manually" : "Until " + NotificationManager.formatTime(NotificationManager.dndEndHour, NotificationManager.dndEndMinute))
                      : NotificationManager.dndScheduleText
                    color: Theme.textMuted
                    font.pixelSize: 12
                  }
                }
              }

              // Configure button (aligned right)
              FocusLink {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Configure"
                textColor: Theme.textMuted
                hoverColor: Theme.accent
                fontSize: 12
                onClicked: NotificationManager.openSettingsNotifications()
              }
            }
          }
        }

        // Notifications list
        ScrollView {
          width: parent.width
          height: parent.height - 32 - 16 - dndColumn.height - 24 - 16 - clearButton.height - 16
          clip: true

          Column {
            width: parent.width
            spacing: 8

            // Empty state
            Item {
              width: parent.width
              height: 120
              visible: NotificationManager.history.length === 0

              Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰂚"
                  color: Theme.textMuted
                  font.pixelSize: 48
                  font.family: "Symbols Nerd Font"
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "All caught up!"
                  color: Theme.textMuted
                  font.pixelSize: 14
                }
              }
            }

            // Grouped notifications
            Repeater {
              model: NotificationManager.history

              Column {
                id: groupColumn
                required property var modelData
                required property int index

                width: parent.width
                spacing: 4

                // Group header
                FocusListItem {
                  itemHeight: 36
                  bodyMargins: 0
                  bodyRadius: 6
                  icon: groupColumn.modelData.expanded ? "󰅀" : "󰅂"
                  iconSize: 12
                  text: groupColumn.modelData.appName + " (" + groupColumn.modelData.notifications.length + ")"
                  fontSize: 13
                  hoverBackgroundColor: Theme.bgCard
                  onClicked: NotificationManager.toggleGroup(groupColumn.modelData.appName)
                }

                // Notifications in group
                Column {
                  width: parent.width
                  spacing: 4
                  visible: groupColumn.modelData.expanded

                  Repeater {
                    model: groupColumn.modelData.notifications

                    NotificationCard {
                      required property var modelData
                      required property int index

                      width: parent.width
                      appName: modelData.appName
                      appIcon: modelData.appIcon
                      summary: modelData.summary
                      body: modelData.body
                      urgency: modelData.urgency
                      showCloseButton: true
                      compact: true

                      onDismissed: {
                        NotificationManager.removeFromHistory(modelData.id)
                      }

                      onClicked: {
                        // Could open the app or do something else
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Clear all button
        FocusButton {
          id: clearButton
          width: parent.width
          height: 40
          text: "Clear All Notifications"
          fontSize: 13
          backgroundColor: Theme.bgCard
          hoverColor: Theme.bgCardHover
          textColor: Theme.textPrimary
          textHoverColor: Theme.danger
          visible: NotificationManager.history.length > 0
          onClicked: NotificationManager.clearHistory()
        }
      }
    }
  }
}
