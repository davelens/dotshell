import Quickshell
import QtQuick
import qs
import qs.core.components

Scope {
  Variants {
    model: PowerManager.menuOpen && ScreenManager.primaryScreen
             ? [ScreenManager.primaryScreen] : []

    PanelBase {
      id: overlay
      namespaceName: "dotshell-power-menu"
      color: "transparent"

    FocusNavigator {
      id: focusNavigator
      root: cardContent
      manageFocusRing: true
    }

    // Auto-select "suspend" when the overlay is created
    Component.onCompleted: Qt.callLater(function() { focusNavigator.focusAt(1) })

    Connections {
      target: PowerManager
      function onPendingActionChanged() {
        if (PowerManager.pendingAction !== "") {
          focusNavigator.reset()
          var focusables = focusNavigator.refresh()
          if (focusables.length > 0)
            focusNavigator.focusAt(focusables.length - 1)
        }
      }
    }

    contentItem {
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape
            || (event.key === Qt.Key_BracketLeft && (event.modifiers & Qt.ControlModifier))) {
          if (PowerManager.pendingAction !== "") {
            focusNavigator.reset()
            PowerManager.cancelAction()
          } else {
            focusNavigator.reset()
            OverlayManager.close("power")
          }
          event.accepted = true
        } else if (event.key === Qt.Key_Q && !(event.modifiers & Qt.ControlModifier)) {
          focusNavigator.reset()
          OverlayManager.close("power")
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

    // Dimmed background - click outside card to close
    Rectangle {
      anchors.fill: parent
      color: Theme.overlay

      MouseArea {
        anchors.fill: parent
        onClicked: OverlayManager.close("power")
      }
    }

    // Centered card
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: 320
      height: cardContent.height + 48
      radius: 12
      color: Theme.bgBase
      border.width: 1
      border.color: Theme.bgBorder

      // Absorb clicks on the card
      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        id: cardContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 0

        // -- User info header ------------------------------------------------

        Column {
          width: parent.width
          spacing: 4
          visible: PowerManager.pendingAction === ""

          Text {
            text: PowerManager.username
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.bold: true
          }

          Text {
            text: PowerManager.uptime
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 13
          }
        }

        // Spacer above separator
        Item {
          width: 1; height: 16
          visible: PowerManager.pendingAction === ""
        }

        // Separator
        Rectangle {
          width: parent.width
          height: 1
          color: Theme.bgBorder
          visible: PowerManager.pendingAction === ""
        }

        // Spacer below separator
        Item {
          width: 1; height: 16
          visible: PowerManager.pendingAction === ""
        }

        // -- Main menu (when no pending action) ------------------------------

        Column {
          id: menuColumn
          width: parent.width
          spacing: 4
          visible: PowerManager.pendingAction === ""

          Repeater {
            model: PowerManager.actions

            Item {
              id: actionItem
              required property var modelData
              required property int index

              width: menuColumn.width
              height: 44

              property bool showFocusRing: true
              property bool keyboardFocus: false
              property bool focused: activeFocus && showFocusRing && keyboardFocus
              property bool hovered: actionMouse.containsMouse
              focus: true
              activeFocusOnTab: true

              onActiveFocusChanged: {
                if (!activeFocus) keyboardFocus = false
              }

              // Focus ring
              Rectangle {
                anchors.centerIn: parent
                width: parent.width + 6
                height: parent.height + 6
                radius: body.radius + 3
                color: "transparent"
                border.width: 2
                border.color: Theme.focusRing
                visible: actionItem.focused
              }

              Rectangle {
                id: body
                anchors.fill: parent
                radius: 6
                color: actionItem.hovered || actionItem.focused ? Theme.bgCardHover : "transparent"

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 12

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: actionItem.modelData.icon
                    color: Theme.textSecondary
                    font.pixelSize: 18
                    font.family: "Symbols Nerd Font"
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: actionItem.modelData.label
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                  }
                }
              }

              MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  actionItem.forceActiveFocus()
                  PowerManager.requestAction(actionItem.modelData.id)
                }
              }

              Keys.onSpacePressed: PowerManager.requestAction(modelData.id)
              Keys.onReturnPressed: PowerManager.requestAction(modelData.id)
              Keys.onEnterPressed: PowerManager.requestAction(modelData.id)
            }
          }
        }

        // -- Confirmation view (when pending action) -------------------------

        Column {
          id: confirmColumn
          width: parent.width
          spacing: 16
          visible: PowerManager.pendingAction !== ""

          Item { width: 1; height: 4 }

          Text {
            width: parent.width
            text: "Are you sure?"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            width: parent.width
            text: {
              var action = PowerManager.actions.find(
                candidate => candidate.id === PowerManager.pendingAction)
              return action ? action.description : ""
            }
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
          }

          Item { width: 1; height: 4 }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            FocusButton {
              width: 120
              height: 40
              text: "󰅖  No"
              fontSize: 14
              backgroundColor: Theme.bgCard
              hoverColor: Theme.bgCardHover
              textColor: Theme.textPrimary
              textHoverColor: Theme.danger
              onClicked: PowerManager.cancelAction()
            }

            FocusButton {
              id: yesButton
              width: 120
              height: 40
              text: "󰄬  Yes"
              fontSize: 14
              backgroundColor: Theme.bgCard
              hoverColor: Theme.bgCardHover
              textColor: Theme.textPrimary
              textHoverColor: Theme.accent
              onClicked: PowerManager.confirmAction()
            }
          }
        }
      }
    }
  }
  }
}
