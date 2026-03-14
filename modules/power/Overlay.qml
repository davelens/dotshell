import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../core/components"

Variants {
  model: ScreenManager.primaryScreen ? [ScreenManager.primaryScreen] : []

  PanelWindow {
    required property var modelData

    id: overlay
    screen: modelData
    // Keep the surface always mapped so the QML tree stays laid out.
    // Use layer switching to prevent input interception when closed.
    visible: true

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "quickshell-power-menu"
    WlrLayershell.layer: PowerManager.menuOpen ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.keyboardFocus: PowerManager.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Keyboard focus cycling state
    property var focusables: []
    property int focusIndex: -1

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
      findFocusables(cardContent, focusables)
    }

    function focusItem(item) {
      if (!item) return
      if (item.keyboardFocus !== undefined) item.keyboardFocus = true
      if (item.showFocusRing !== undefined) item.showFocusRing = true
      if (item.forceActiveFocus) item.forceActiveFocus()
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

    Connections {
      target: PowerManager
      function onPendingActionChanged() {
        if (PowerManager.pendingAction !== "") {
          overlay.resetFocus()
          overlay.refreshFocusables()
          if (overlay.focusables.length > 0) {
            overlay.focusIndex = overlay.focusables.length - 1
            overlay.focusItem(overlay.focusables[overlay.focusIndex])
          }
        }
      }
    }

    contentItem {
      focus: PowerManager.menuOpen
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape
            || (event.key === Qt.Key_BracketLeft && (event.modifiers & Qt.ControlModifier))) {
          if (PowerManager.pendingAction !== "") {
            overlay.resetFocus()
            PowerManager.cancelAction()
          } else {
            overlay.resetFocus()
            PowerManager.close()
          }
          event.accepted = true
        } else if (event.key === Qt.Key_Q && !(event.modifiers & Qt.ControlModifier)) {
          overlay.resetFocus()
          PowerManager.close()
          event.accepted = true
        } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
          overlay.focusNext()
          event.accepted = true
        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
          overlay.focusPrevious()
          event.accepted = true
        }
      }
    }

    // Dimmed background - click outside card to close
    Rectangle {
      anchors.fill: parent
      color: Theme.overlay
      visible: PowerManager.menuOpen

      MouseArea {
        anchors.fill: parent
        onClicked: PowerManager.close()
      }
    }

    // Centered card
    Rectangle {
      id: card
      anchors.centerIn: parent
      visible: PowerManager.menuOpen
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
            font.pixelSize: 16
            font.bold: true
          }

          Text {
            text: PowerManager.uptime
            color: Theme.textSecondary
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
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            width: parent.width
            text: PowerManager.getDescription(PowerManager.pendingAction)
            color: Theme.textSecondary
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
