import Quickshell
import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

ModulePopup {
  id: bluetoothPopup

  // The popup owns a continuous discovery request for its whole lifetime.
  onIsOpenChanged: {
    if (isOpen) {
      BluetoothManager.clearErrors()
      BluetoothManager.startScan(true)
    } else {
      BluetoothManager.stopScan()
    }
  }

  PopupBase {
    popupWidth: 380
    contentSpacing: 12

    popupHeight: {
      // Header (28) + spacing (12) + separator (1) + spacing (12)
      var h = 28 + 12 + 1 + 12

      if (!BluetoothManager.powered) {
        h += 50
      } else {
        var connectedCount = BluetoothManager.connectedDevices.length
        if (connectedCount > 0) {
          // Label, rows, separator, and section spacing.
          h += 16 + 4 + connectedCount * 36 + (connectedCount - 1) * 4 + 12 + 1 + 12
        }

        h += 20 + 12

        var availableDevices = BluetoothManager.devices.filter(function(device) {
          return !device.connected
        })
        if (availableDevices.length > 0) {
          var displayCount = Math.min(availableDevices.length, 6)
          h += displayCount * 36 + (displayCount - 1) * 2
        } else {
          h += 40
        }

        if (BluetoothManager.connectError) h += 24
      }

      if (BluetoothManager.globalError) h += 24
      return h + 48
    }

    // Header with power toggle
    Item {
      width: parent.width
      height: 28

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: BluetoothManager.getIcon()
          color: BluetoothManager.powered ? Theme.accent : Theme.textMuted
          font.pixelSize: Theme.scaledFontSize(20)
          font.family: "Symbols Nerd Font"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Bluetooth"
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: Theme.scaledFontSize(16)
        }
      }

      SwitchToggle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: BluetoothManager.powered
        enabled: !BluetoothManager.busy
        opacity: enabled ? 1 : 0.5
        onClicked: BluetoothManager.togglePower()
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
      visible: BluetoothManager.powered
    }

    // Connected devices. The row disconnects; its separate trash action forgets.
    Column {
      width: parent.width
      spacing: 4
      visible: BluetoothManager.connectedDevices.length > 0

      TitleText {
        text: "Connected devices"
      }

      Repeater {
        model: BluetoothManager.connectedDevices

        Column {
          required property var modelData
          readonly property bool known: modelData.paired || modelData.bonded || modelData.trusted
          readonly property string displayText: {
            if (BluetoothManager.deviceActionAddress !== modelData.address) return modelData.name
            if (BluetoothManager.deviceAction === "disconnect")
              return modelData.name + "  —  Disconnecting..."
            if (BluetoothManager.deviceAction === "forget")
              return modelData.name + "  —  Forgetting..."
            return modelData.name
          }

          width: parent.width
          spacing: 0

          Row {
            width: parent.width
            height: 36
            spacing: 6

            FocusListItem {
              width: parent.width - (connectedForgetButton.visible
                ? connectedForgetButton.width + parent.spacing : 0)
              itemHeight: 36
              bodyMargins: 0
              bodyRadius: 4
              contentLeftMargin: 0
              icon: "󰂱"
              iconSize: 18
              iconColor: BluetoothManager.deviceActionAddress === modelData.address
                ? Theme.accent : Theme.success
              text: displayText
              fontSize: 15
              rightIcon: "󰅖"
              rightIconColor: Theme.textMuted
              rightIconHoverColor: Theme.danger
              backgroundColor: Theme.bgCardHover
              hoverBackgroundColor: Theme.bgCardHover
              enabled: !BluetoothManager.busy
              opacity: enabled ? 1 : 0.7
              onClicked: BluetoothManager.disconnect(modelData.address)
            }

            FocusIconButton {
              id: connectedForgetButton
              anchors.verticalCenter: parent.verticalCenter
              icon: "󰆴"
              iconSize: 16
              iconColor: Theme.textMuted
              hoverColor: Theme.danger
              visible: known
              enabled: !BluetoothManager.busy
              opacity: enabled ? 1 : 0.5
              onClicked: BluetoothManager.forget(modelData.address)
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

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
      visible: BluetoothManager.connectedDevices.length > 0
    }

    // Scanning indicator / devices header
    Item {
      width: parent.width
      height: 20
      visible: BluetoothManager.powered

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        TitleText {
          anchors.verticalCenter: parent.verticalCenter
          text: BluetoothManager.scanning ? "Scanning..." : "Available devices"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰔟"
          color: Theme.accent
          font.pixelSize: Theme.scaledFontSize(14)
          font.family: "Symbols Nerd Font"
          visible: BluetoothManager.scanning

          RotationAnimation on rotation {
            running: BluetoothManager.scanning
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
          }
        }
      }

      FocusIconButton {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰑐"
        iconSize: 16
        hoverColor: Theme.accent
        visible: !BluetoothManager.scanning
        onClicked: BluetoothManager.startScan(true)
      }
    }

    // Device list (scrollable, max 6 visible)
    ScrollView {
      id: deviceScroll
      width: parent.width
      visible: BluetoothManager.powered
      clip: true
      contentWidth: availableWidth

      readonly property var availableDevices: BluetoothManager.devices.filter(function(device) {
        return !device.connected
      })

      height: {
        if (availableDevices.length === 0) return 40
        var displayCount = Math.min(availableDevices.length, 6)
        var h = displayCount * 36 + (displayCount - 1) * 2
        var errorIsAvailable = availableDevices.some(function(device) {
          return device.address === BluetoothManager.connectErrorAddress
        })
        if (BluetoothManager.connectError && errorIsAvailable) h += 24
        return h
      }

      Column {
        width: parent.width
        spacing: 2

        Repeater {
          model: deviceScroll.availableDevices

          Column {
            required property var modelData
            readonly property bool known: modelData.paired || modelData.bonded || modelData.trusted
            readonly property string displayText: {
              if (BluetoothManager.deviceActionAddress !== modelData.address) return modelData.name
              if (BluetoothManager.deviceAction === "pair")
                return modelData.name + "  —  Pairing..."
              if (BluetoothManager.deviceAction === "connect")
                return modelData.name + "  —  Connecting..."
              if (BluetoothManager.deviceAction === "forget")
                return modelData.name + "  —  Forgetting..."
              return modelData.name
            }

            width: parent.width
            spacing: 0

            Row {
              width: parent.width
              height: 36
              spacing: 6

              FocusListItem {
                width: parent.width - (availableForgetButton.visible
                  ? availableForgetButton.width + parent.spacing : 0)
                itemHeight: 36
                bodyMargins: 0
                bodyRadius: 4
                contentLeftMargin: 0
                icon: known ? "󰂰" : "󰂯"
                iconSize: 18
                iconColor: BluetoothManager.deviceActionAddress === modelData.address
                  ? Theme.accent : (known ? Theme.accent : Theme.textMuted)
                text: displayText
                fontSize: 15
                hoverBackgroundColor: Theme.bgCard
                enabled: !BluetoothManager.busy
                opacity: enabled ? 1 : 0.7
                onClicked: BluetoothManager.connect(modelData.address)
              }

              FocusIconButton {
                id: availableForgetButton
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰆴"
                iconSize: 16
                iconColor: Theme.textMuted
                hoverColor: Theme.danger
                visible: known
                enabled: !BluetoothManager.busy
                opacity: enabled ? 1 : 0.5
                onClicked: BluetoothManager.forget(modelData.address)
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

        BodyText {
          width: parent.width
          text: BluetoothManager.scanning ? "Looking for devices..." : "No devices found"
          horizontalAlignment: Text.AlignHCenter
          visible: deviceScroll.availableDevices.length === 0
          topPadding: 8
          bottomPadding: 8
        }
      }
    }

    // Bluetooth off state
    Column {
      width: parent.width
      spacing: 8
      visible: !BluetoothManager.powered

      Text {
        width: parent.width
        text: "Bluetooth is off"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(15)
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
      }

      Text {
        width: parent.width
        text: "Toggle the switch above to enable"
        color: Theme.textSubtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(13)
        horizontalAlignment: Text.AlignHCenter
        bottomPadding: 8
      }
    }

    // Radio and discovery failures are not tied to a device row.
    Text {
      width: parent.width
      text: BluetoothManager.globalError
      color: Theme.danger
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(12)
      leftPadding: 10
      wrapMode: Text.WordWrap
      visible: BluetoothManager.globalError !== ""
    }
  }
}
