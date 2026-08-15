import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

// Notification history panel - slides in from right
Scope {
  id: root

  // One-way latch: create the PanelWindow on first open, then keep it
  // alive so the QML tree stays laid out and the slide animation is smooth.
  property bool panelVisible: false

  Connections {
    target: NotificationManager
    function onPanelOpenChanged() {
      if (NotificationManager.panelOpen) {
        root.panelVisible = true
      }
    }
  }

  Variants {
    model: root.panelVisible && ScreenManager.primaryScreen
             ? [ScreenManager.primaryScreen] : []

    PanelWindow {
      required property var modelData

      id: panel
      screen: modelData
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

      WlrLayershell.namespace: "dotshell-notification-panel"
      // Stay on Overlay while open or while the slide-out animation is
      // running, then drop to Background so the surface doesn't intercept
      // clicks.
      property bool animating: false
      WlrLayershell.layer: (NotificationManager.panelOpen || panel.animating)
        ? WlrLayer.Overlay : WlrLayer.Background
      WlrLayershell.keyboardFocus: NotificationManager.panelOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      Connections {
        target: NotificationManager
        function onPanelOpenChanged() {
          if (!NotificationManager.panelOpen) panel.animating = true
        }
      }

      FocusNavigator {
        id: focusNavigator
        root: panelColumn
        manageFocusRing: true
        scrollEnabled: true
      }

      contentItem {
        focus: NotificationManager.panelOpen
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q
              || (event.key === Qt.Key_BracketLeft && (event.modifiers & Qt.ControlModifier))) {
            focusNavigator.reset()
            OverlayManager.close("notifications")
            event.accepted = true
          } else if (event.key === Qt.Key_C && !(event.modifiers & Qt.ControlModifier)) {
            NotificationManager.clearHistory()
            event.accepted = true
          } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
            focusNavigator.focusNext()
            event.accepted = true
          } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            focusNavigator.focusPrevious()
            event.accepted = true
          }
        }
      }

      // Ensure the panel starts offscreen on first creation so the
      // Behavior has an actual value change to animate.
      property bool slideIn: false
      Component.onCompleted: Qt.callLater(function() { panel.slideIn = true })

      // Click outside to close
      MouseArea {
        anchors.fill: parent
        enabled: NotificationManager.panelOpen
        onClicked: OverlayManager.close("notifications")
      }

      // Panel content
      // Extends 2px beyond window edges (top, right, bottom) so the compositor
      // clips those edges instead of rendering a visible seam at fractional scaling.
      Rectangle {
        id: panelContent
        anchors.top: parent.top
        anchors.topMargin: -2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        anchors.right: parent.right
        anchors.rightMargin: (panel.slideIn && NotificationManager.panelOpen) ? -2 : -(width + 1)
        width: 382
        color: Theme.bgBase

        Behavior on anchors.rightMargin {
          NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
            onRunningChanged: {
              if (!running && !NotificationManager.panelOpen) {
                panel.animating = false
              }
            }
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
              onClicked: OverlayManager.close("notifications")
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
                  onClicked: OverlayManager.open("settings", { category: "notifications" })
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
                        timestamp: modelData.timestamp
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
}
