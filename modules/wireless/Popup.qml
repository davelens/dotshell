import Quickshell
import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

ModulePopup {
  id: wirelessPopup

  onIsOpenChanged: {
    if (isOpen) {
      WirelessManager.clearFailure()
      WirelessManager.startScanning()
    } else {
      WirelessManager.stopScanning()
      WirelessManager.cancelPending()
    }
  }

  PopupBase {
    id: popupBase
    popupWidth: 380
    contentSpacing: 12

    readonly property int availableNetworkCount: {
      var count = 0
      for (var i = 0; i < WirelessManager.networks.count; i++) {
        if (!WirelessManager.networks.get(i).connected) count++
      }
      return count
    }

    function networkExists(key) {
      if (!key) return false
      for (var i = 0; i < WirelessManager.networks.count; i++) {
        if (WirelessManager.networks.get(i).networkKey === key) return true
      }
      return false
    }

    function availableNetworkExists(key) {
      if (!key) return false
      for (var i = 0; i < WirelessManager.networks.count; i++) {
        var network = WirelessManager.networks.get(i)
        if (!network.connected && network.networkKey === key) return true
      }
      return false
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
          text: WirelessManager.getIcon()
          color: WirelessManager.enabled ? Theme.accent : Theme.textMuted
          font.pixelSize: Theme.scaledFontSize(20)
          font.family: "Symbols Nerd Font"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Wi-Fi"
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: Theme.scaledFontSize(16)
        }
      }

      SwitchToggle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: WirelessManager.enabled
        enabled: WirelessManager.backendAvailable && WirelessManager.hardwareEnabled
          && !WirelessManager.busy
        opacity: enabled ? 1 : 0.5
        onClicked: WirelessManager.toggleEnabled()
      }
    }

    Text {
      width: parent.width
      text: WirelessManager.actionMessage
      color: Theme.accent
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(12)
      wrapMode: Text.WordWrap
      visible: WirelessManager.actionKind !== "" && WirelessManager.actionKey === ""
    }

    Text {
      width: parent.width
      text: WirelessManager.failureMessage
      color: Theme.danger
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(12)
      wrapMode: Text.WordWrap
      visible: WirelessManager.failureMessage !== ""
        && (!WirelessManager.failureKey || !popupBase.networkExists(WirelessManager.failureKey))
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
      visible: WirelessManager.enabled
    }

    // Connected network. Disconnect and forget remain separate focus targets.
    Column {
      id: connectedSection
      width: parent.width
      spacing: 6
      visible: WirelessManager.connectedNetwork !== null

      readonly property var network: WirelessManager.connectedNetwork
      readonly property string networkKey: network ? network.networkKey : ""
      readonly property string rowText: {
        if (!network) return ""
        if (WirelessManager.actionKey === networkKey && WirelessManager.actionMessage)
          return network.ssid + "  —  " + WirelessManager.actionMessage
        if (network.stateChanging) return network.ssid + "  —  Updating…"
        return network.ssid
      }

      TitleText {
        text: "Connected network"
      }

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
          icon: WirelessManager.getIcon()
          iconSize: 18
          iconColor: WirelessManager.actionKey === connectedSection.networkKey
            ? Theme.accent : Theme.success
          text: connectedSection.rowText
          fontSize: 15
          rightIcon: "󰅖"
          rightIconColor: Theme.textMuted
          rightIconHoverColor: Theme.danger
          backgroundColor: Theme.bgCardHover
          hoverBackgroundColor: Theme.bgCardHover
          enabled: !WirelessManager.busy
          opacity: enabled ? 1 : 0.7
          onClicked: WirelessManager.disconnect(connectedSection.networkKey)
        }

        FocusIconButton {
          id: connectedForgetButton
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰆴"
          iconSize: 16
          iconColor: Theme.textMuted
          hoverColor: Theme.danger
          visible: connectedSection.network ? connectedSection.network.known : false
          enabled: !WirelessManager.busy
          opacity: enabled ? 1 : 0.5
          onClicked: WirelessManager.forget(connectedSection.networkKey)
        }
      }

      Text {
        width: parent.width
        text: WirelessManager.failureMessage
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(12)
        leftPadding: 10
        wrapMode: Text.WordWrap
        visible: WirelessManager.failureKey === parent.networkKey
          && WirelessManager.failureMessage !== ""
      }

      Text {
        text: "Uptime: " + WirelessManager.getConnectionDurationLong()
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(14)
        leftPadding: 10
        visible: WirelessManager.connectionTimestamp > 0
      }

      Text {
        text: "Down: " + WirelessManager.formatSpeed(WirelessManager.downloadSpeed)
          + "  Up: " + WirelessManager.formatSpeed(WirelessManager.uploadSpeed)
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(14)
        leftPadding: 10
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
      visible: WirelessManager.connectedNetwork !== null
    }

    // Networks header
    Item {
      width: parent.width
      height: 20
      visible: WirelessManager.enabled

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        TitleText {
          anchors.verticalCenter: parent.verticalCenter
          text: WirelessManager.scanning ? "Scanning..." : "Available networks"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰔟"
          color: Theme.accent
          font.pixelSize: Theme.scaledFontSize(14)
          font.family: "Symbols Nerd Font"
          visible: WirelessManager.scanning

          RotationAnimation on rotation {
            running: WirelessManager.scanning
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
          }
        }
      }

      FocusIconButton {
        id: availableNetworksRefresh
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰑐"
        iconSize: 16
        hoverColor: Theme.accent
        visible: !WirelessManager.scanning
        enabled: !WirelessManager.busy
        opacity: enabled ? 1 : 0.5
        onClicked: WirelessManager.startScanning()
      }
    }

    // Network list (scrollable, max 6 visible)
    ScrollView {
      width: parent.width
      visible: WirelessManager.enabled
      clip: true
      contentWidth: availableWidth

      height: {
        if (popupBase.availableNetworkCount === 0) return 40
        var displayCount = Math.min(popupBase.availableNetworkCount, 6)
        var h = displayCount * 36 + (displayCount - 1) * 2
        if (popupBase.availableNetworkExists(WirelessManager.pendingNetworkKey)) h += 40
        if (WirelessManager.failureMessage
            && popupBase.availableNetworkExists(WirelessManager.failureKey)) h += 20
        return h
      }

      Column {
        width: parent.width
        spacing: 2

        Repeater {
          model: WirelessManager.networks

          Column {
            id: networkDelegate
            required property string networkKey
            required property string ssid
            required property int signal
            required property bool secured
            required property bool known
            required property bool connected
            required property bool stateChanging

            readonly property bool isPending: WirelessManager.pendingNetworkKey === networkKey
            readonly property bool hasAction: WirelessManager.actionKey === networkKey
              && WirelessManager.actionMessage !== ""
            readonly property string rowText: {
              if (hasAction) return ssid + "  —  " + WirelessManager.actionMessage
              if (stateChanging) return ssid + "  —  Updating…"
              return ssid
            }

            width: parent.width
            spacing: 0
            visible: !connected

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
                icon: WirelessManager.getSignalIcon(networkDelegate.signal)
                iconSize: 18
                iconColor: networkDelegate.hasAction ? Theme.accent : Theme.textMuted
                text: networkDelegate.rowText
                fontSize: 15
                rightIcon: networkDelegate.secured ? "󰌾" : ""
                hoverBackgroundColor: Theme.bgCard
                enabled: !WirelessManager.busy
                opacity: enabled ? 1 : 0.7
                onClicked: WirelessManager.connect(networkDelegate.networkKey)
              }

              FocusIconButton {
                id: availableForgetButton
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰆴"
                iconSize: 16
                iconColor: Theme.textMuted
                hoverColor: Theme.danger
                visible: networkDelegate.known
                enabled: !WirelessManager.busy
                opacity: enabled ? 1 : 0.5
                onClicked: WirelessManager.forget(networkDelegate.networkKey)
              }
            }

            // Inline password input
            Column {
              width: parent.width
              spacing: 4
              visible: networkDelegate.isPending
              topPadding: 4

              onVisibleChanged: {
                if (visible) {
                  passwordInput.clear()
                  passwordInput.focusInput()
                }
              }

              PasswordInput {
                id: passwordInput
                onSubmitted: function(password) {
                  WirelessManager.connectWithPsk(networkDelegate.networkKey, password)
                }
                onCancelled: WirelessManager.cancelPending()
              }
            }

            Text {
              width: parent.width
              text: WirelessManager.failureMessage
              color: Theme.danger
              font.family: Theme.fontFamily
              font.pixelSize: Theme.scaledFontSize(12)
              leftPadding: 10
              topPadding: 4
              wrapMode: Text.WordWrap
              visible: WirelessManager.failureKey === networkDelegate.networkKey
                && WirelessManager.failureMessage !== ""
            }
          }
        }

        BodyText {
          width: parent.width
          text: WirelessManager.scanning ? "Looking for networks..." : "No networks found"
          horizontalAlignment: Text.AlignHCenter
          visible: popupBase.availableNetworkCount === 0
          topPadding: 8
          bottomPadding: 8
        }
      }
    }

    // Wi-Fi off state
    Column {
      width: parent.width
      spacing: 8
      visible: !WirelessManager.enabled

      Text {
        width: parent.width
        text: !WirelessManager.backendAvailable ? "NetworkManager is unavailable"
          : !WirelessManager.hardwareEnabled ? "Wi-Fi hardware is disabled"
          : "Wi-Fi is off"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(15)
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
      }

      Text {
        width: parent.width
        text: WirelessManager.backendAvailable && WirelessManager.hardwareEnabled
          ? "Toggle the switch above to enable" : ""
        color: Theme.textSubtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(13)
        horizontalAlignment: Text.AlignHCenter
        bottomPadding: 8
        visible: text !== ""
      }
    }
  }
}
