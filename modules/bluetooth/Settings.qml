import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

SettingsPage {
  id: settingsRoot
  contentSpacing: 16
  Component.onCompleted: BluetoothManager.clearErrors()

  Row {
    spacing: 16

    Text {
      text: "Bluetooth"
      color: Theme.textPrimary
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(24)
      font.bold: true
    }

    SwitchToggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: BluetoothManager.powered
      enabled: !BluetoothManager.busy
      opacity: enabled ? 1 : 0.5
      onClicked: BluetoothManager.togglePower()
    }
  }

  Text {
    width: parent.width
    text: BluetoothManager.globalError
    color: Theme.danger
    font.family: Theme.fontFamily
    font.pixelSize: Theme.scaledFontSize(12)
    wrapMode: Text.WordWrap
    visible: BluetoothManager.globalError !== ""
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

      Column {
        required property var modelData
        required property int index
        readonly property bool known: modelData.paired || modelData.bonded || modelData.trusted
        readonly property string statusText: {
          if (BluetoothManager.deviceActionAddress !== modelData.address) return "Connected"
          if (BluetoothManager.deviceAction === "disconnect") return "Disconnecting..."
          if (BluetoothManager.deviceAction === "forget") return "Forgetting..."
          return "Connected"
        }

        width: parent.width
        spacing: 0

        Rectangle {
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
              font.pixelSize: Theme.scaledFontSize(18)
              font.family: "Symbols Nerd Font"
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                text: modelData.name
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.scaledFontSize(14)
              }

              Text {
                text: statusText
                color: BluetoothManager.deviceActionAddress === modelData.address
                  ? Theme.accent : Theme.success
                font.family: Theme.fontFamily
                font.pixelSize: Theme.scaledFontSize(12)
              }
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            FocusLink {
              text: "Disconnect"
              enabled: !BluetoothManager.busy
              opacity: enabled ? 1 : 0.5
              onClicked: BluetoothManager.disconnect(modelData.address)
            }

            FocusLink {
              text: "Forget"
              visible: known
              enabled: !BluetoothManager.busy
              opacity: enabled ? 1 : 0.5
              onClicked: BluetoothManager.forget(modelData.address)
            }
          }
        }

        Text {
          width: parent.width
          text: BluetoothManager.connectError
          color: Theme.danger
          font.family: Theme.fontFamily
          font.pixelSize: Theme.scaledFontSize(12)
          leftPadding: 10
          topPadding: 4
          wrapMode: Text.WordWrap
          visible: BluetoothManager.connectErrorAddress === modelData.address
            && BluetoothManager.connectError !== ""
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
        enabled: !BluetoothManager.busy
        opacity: enabled ? 1 : 0.5
        onClicked: BluetoothManager.startScan(false)
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
          readonly property bool known: modelData.paired || modelData.bonded || modelData.trusted
          readonly property string actionText: {
            if (BluetoothManager.deviceActionAddress !== modelData.address) return ""
            if (BluetoothManager.deviceAction === "pair") return "Pairing..."
            if (BluetoothManager.deviceAction === "connect") return "Connecting..."
            if (BluetoothManager.deviceAction === "forget") return "Forgetting..."
            return ""
          }

          width: parent.width
          spacing: 0

          Row {
            width: parent.width
            spacing: 12

            FocusListItem {
              width: parent.width - (availableForgetButton.visible
                ? availableForgetButton.width + parent.spacing : 0)
              icon: known ? "󰂰" : "󰂯"
              iconColor: actionText !== "" ? Theme.accent
                : (known ? Theme.accent : Theme.textMuted)
              text: actionText !== "" ? modelData.name + "  —  " + actionText : modelData.name
              subtitle: actionText !== "" ? "" : (known ? "Known device" : "Not paired")
              enabled: !BluetoothManager.busy
              opacity: enabled ? 1 : 0.7
              onClicked: BluetoothManager.connect(modelData.address)
            }

            FocusLink {
              id: availableForgetButton
              anchors.verticalCenter: parent.verticalCenter
              text: "Forget"
              visible: known
              enabled: !BluetoothManager.busy
              opacity: enabled ? 1 : 0.5
              onClicked: BluetoothManager.forget(modelData.address)
            }
          }

          // Inline error for this device
          Text {
            width: parent.width
            text: BluetoothManager.connectError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: Theme.scaledFontSize(12)
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
