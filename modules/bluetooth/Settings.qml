import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

ScrollView {
  id: settingsRoot
  anchors.fill: parent
  clip: true
  contentWidth: availableWidth
  Component.onCompleted: {
    BluetoothManager.connectError = ""
    BluetoothManager.connectErrorAddress = ""
  }

  // Search query passed from SettingsPanel
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
    spacing: 16

    Row {
      spacing: 16

      Text {
        text: "Bluetooth"
        color: Theme.textPrimary
        font.pixelSize: 24
        font.bold: true
      }

      SwitchToggle {
        anchors.verticalCenter: parent.verticalCenter
        checked: BluetoothManager.powered
        onClicked: BluetoothManager.togglePower()
      }
    }

    // Connected devices list
    Column {
      width: parent.width
      spacing: 8
      visible: BluetoothManager.powered && BluetoothManager.connectedDevices.length > 0

      TitleText {
        text: settingsRoot.highlightText("Connected devices", settingsRoot.searchQuery)
        textFormat: Text.RichText
      }

      Repeater {
        model: BluetoothManager.connectedDevices

        Rectangle {
          required property var modelData
          required property int index

          width: parent.width
          height: 64
          radius: 8
          color: Theme.bgCard

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰂱"
              color: Theme.accent
              font.pixelSize: 18
              font.family: "Symbols Nerd Font"
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                text: modelData.name
                color: Theme.textPrimary
                font.pixelSize: 14
              }

              Text {
                text: settingsRoot.highlightText("Connected", settingsRoot.searchQuery)
                textFormat: Text.RichText
                color: Theme.success
                font.pixelSize: 12
              }
            }
          }

          FocusLink {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Disconnect"
            onClicked: BluetoothManager.disconnect(modelData.address)
          }
        }
      }
    }

    // Separator after connected devices
    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
      visible: BluetoothManager.powered && BluetoothManager.connectedDevices.length > 0
    }

    // Devices section with header and list
    Column {
      width: parent.width
      spacing: 6
      visible: BluetoothManager.powered

      Row {
        spacing: 8

        TitleText {
          text: BluetoothManager.scanning ? "Scanning..." : settingsRoot.highlightText("Available Devices", settingsRoot.searchQuery)
          textFormat: Text.RichText
        }

        FocusIconButton {
          icon: "󰑐"
          visible: !BluetoothManager.scanning
          onClicked: BluetoothManager.startScan()
        }
      }

      // Device list (paired but not connected, and discovered)
      Column {
        width: parent.width
        spacing: 2

        Repeater {
          model: BluetoothManager.devices.filter(function(d) { return !d.connected })

          Column {
            required property var modelData
            width: parent.width
            spacing: 0

            FocusListItem {
              property bool isConnecting: BluetoothManager.connectingAddress === modelData.address

              icon: modelData.paired ? "󰂰" : "󰂯"
              iconColor: isConnecting ? Theme.accent : (modelData.paired ? Theme.accent : Theme.textMuted)
              text: isConnecting ? modelData.name + "  —  Connecting..." : modelData.name
              subtitle: isConnecting ? "" : (modelData.paired ? "Paired" : "Not paired")
              onClicked: {
                if (!BluetoothManager.busy) {
                  BluetoothManager.connect(modelData.address)
                }
              }
            }

            // Inline error for this device
            Text {
              width: parent.width
              text: BluetoothManager.connectError
              color: Theme.danger
              font.pixelSize: 12
              leftPadding: 10
              topPadding: 4
              wrapMode: Text.WordWrap
              visible: BluetoothManager.connectErrorAddress === modelData.address
                && BluetoothManager.connectError !== ""
            }
          }
        }

        // Empty state
        BodyText {
          text: BluetoothManager.scanning ? "Looking for devices..." : "No devices found"
          visible: BluetoothManager.devices.filter(function(d) { return !d.connected }).length === 0
          topPadding: 8
        }
      }
    }

    // Bluetooth off state
    Column {
      width: parent.width
      spacing: 8
      visible: !BluetoothManager.powered

      BodyText {
        text: "Bluetooth is off"
        topPadding: 16
      }

      BodyText {
        text: "Turn on Bluetooth to connect to devices"
      }
    }
  }
}
