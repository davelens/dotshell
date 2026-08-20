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

      readonly property var historyRows: {
        var rows = []
        for (var i = 0; i < NotificationManager.history.length; i++) {
          var group = NotificationManager.history[i]
          rows.push({ kind: "group", group: group })
          if (group.expanded) {
            for (var j = 0; j < group.notifications.length; j++)
              rows.push({ kind: "notification", notification: group.notifications[j] })
          }
        }
        return rows
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
              font.family: Theme.fontFamily
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
                      font.family: Theme.fontFamily
                      font.pixelSize: 14
                    }

                    Text {
                      text: NotificationManager.isDndActive
                        ? (NotificationManager.dndEnabled ? "Enabled manually" : "Until " + NotificationManager.formatTime(NotificationManager.dndEndHour, NotificationManager.dndEndMinute))
                        : NotificationManager.dndScheduleText
                      color: Theme.textMuted
                      font.family: Theme.fontFamily
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
          Item {
            width: parent.width
            height: parent.height - 32 - 16 - dndColumn.height - 24 - 16 - clearButton.height - 16

            Column {
              anchors.centerIn: parent
              spacing: 8
              visible: panel.historyRows.length === 0

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
                font.family: Theme.fontFamily
                font.pixelSize: 14
              }
            }

            FocusScope {
              id: historyFocus
              anchors.fill: parent
              visible: panel.historyRows.length > 0
              activeFocusOnTab: true

              property bool showFocusRing: true
              property bool keyboardFocus: false

              onActiveFocusChanged: {
                if (!activeFocus) keyboardFocus = false
              }

              ListView {
                id: historyList
                anchors.fill: parent
                clip: true
                focus: true
                spacing: 4
                model: panel.historyRows
                reuseItems: true
                cacheBuffer: height

                Keys.onPressed: function(event) {
                  var ctrl = event.modifiers & Qt.ControlModifier
                  if (ctrl && event.key === Qt.Key_N && currentIndex < count - 1) {
                    incrementCurrentIndex()
                    event.accepted = true
                  } else if (ctrl && event.key === Qt.Key_P && currentIndex > 0) {
                    decrementCurrentIndex()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Y && currentIndex >= 0) {
                    var row = panel.historyRows[currentIndex]
                    if (row.kind === "notification") {
                      Quickshell.clipboardText = row.notification.body || row.notification.summary
                      event.accepted = true
                    }
                  } else if (event.key === Qt.Key_Delete && currentIndex >= 0) {
                    var deleteRow = panel.historyRows[currentIndex]
                    if (deleteRow.kind === "notification") {
                      NotificationManager.removeFromHistory(deleteRow.notification.id)
                      event.accepted = true
                    }
                  } else if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return
                              || event.key === Qt.Key_Enter) && currentIndex >= 0) {
                    var activateRow = panel.historyRows[currentIndex]
                    if (activateRow.kind === "group") {
                      NotificationManager.toggleGroup(activateRow.group.appName)
                      event.accepted = true
                    }
                  }
                }

                delegate: FocusScope {
                  id: historyRow

                  required property var modelData
                  required property int index

                  property bool focusNavigationSkip: true

                  width: historyList.width
                  height: rowLoader.height
                  focus: ListView.isCurrentItem

                  Loader {
                    id: rowLoader
                    width: parent.width
                    height: item ? item.height : 0
                    sourceComponent: historyRow.modelData.kind === "group"
                      ? groupRowComponent : notificationRowComponent

                    property var rowData: historyRow.modelData
                    property int rowIndex: historyRow.index
                  }

                  Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.focusRing
                    visible: historyFocus.keyboardFocus
                      && historyList.currentIndex === historyRow.index
                    z: 1
                  }
                }
              }
            }

            Component {
              id: groupRowComponent

              FocusListItem {
                width: parent.width
                itemHeight: 36
                bodyMargins: 0
                bodyRadius: 6
                icon: parent.rowData.group.expanded ? "󰅀" : "󰅂"
                iconSize: 12
                text: parent.rowData.group.appName + " ("
                  + parent.rowData.group.notifications.length + ")"
                fontSize: 13
                hoverBackgroundColor: Theme.bgCard
                showFocusRing: false
                activeFocusOnTab: false
                onClicked: {
                  historyList.currentIndex = parent.rowIndex
                  NotificationManager.toggleGroup(parent.rowData.group.appName)
                }
              }
            }

            Component {
              id: notificationRowComponent

              NotificationCard {
                width: parent.width
                appName: parent.rowData.notification.appName
                appIcon: parent.rowData.notification.appIcon
                summary: parent.rowData.notification.summary
                body: parent.rowData.notification.body
                urgency: parent.rowData.notification.urgency
                timestamp: parent.rowData.notification.timestamp
                showCloseButton: true
                showFocusRing: false
                activeFocusOnTab: false
                compact: true

                onClicked: {
                  historyList.currentIndex = parent.rowIndex
                  historyFocus.forceActiveFocus()
                }

                onDismissed: {
                  historyList.currentIndex = parent.rowIndex
                  NotificationManager.removeFromHistory(parent.rowData.notification.id)
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
