import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

SettingsPage {
  id: settingsRoot
  contentSpacing: 16
  Component.onCompleted: WirelessManager.clearFailure()

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

  Row {
    spacing: 16

    Text {
      text: "Wireless"
      color: Theme.textPrimary
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(24)
      font.bold: true
    }

    SwitchToggle {
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
      && (!WirelessManager.failureKey || !settingsRoot.networkExists(WirelessManager.failureKey))
  }

  Column {
    id: connectedSection
    width: parent.width
    spacing: 8
    visible: WirelessManager.connectedNetwork !== null

    readonly property var network: WirelessManager.connectedNetwork
    readonly property string networkKey: network ? network.networkKey : ""
    readonly property string statusText: {
      if (!network) return ""
      if (WirelessManager.actionKey === networkKey && WirelessManager.actionMessage)
        return WirelessManager.actionMessage
      if (network.stateChanging) return "Updating…"
      return "Connected"
    }

    TitleText {
      text: settingsRoot.highlightText("Connected network", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: 80
      radius: 8
      color: Theme.bgCard

      Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
          text: connectedSection.network ? connectedSection.network.ssid : ""
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: Theme.scaledFontSize(16)
        }

        Text {
          text: connectedSection.statusText
          color: WirelessManager.actionKey === connectedSection.networkKey
            ? Theme.accent : Theme.success
          font.family: Theme.fontFamily
          font.pixelSize: Theme.scaledFontSize(12)
        }

        Row {
          spacing: 16

          Text {
            text: "Down: " + WirelessManager.formatSpeed(WirelessManager.downloadSpeed)
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.scaledFontSize(12)
          }

          Text {
            text: "Up: " + WirelessManager.formatSpeed(WirelessManager.uploadSpeed)
            color: Theme.textMuted
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
          enabled: !WirelessManager.busy
          opacity: enabled ? 1 : 0.5
          onClicked: WirelessManager.disconnect(connectedSection.networkKey)
        }

        FocusLink {
          text: "Forget"
          visible: connectedSection.network ? connectedSection.network.known : false
          enabled: !WirelessManager.busy
          opacity: enabled ? 1 : 0.5
          onClicked: WirelessManager.forget(connectedSection.networkKey)
        }
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
  }

  Rectangle {
    width: parent.width
    height: 1
    color: Theme.bgCardHover
    visible: WirelessManager.connectedNetwork !== null
  }

  Column {
    width: parent.width
    spacing: 6
    visible: WirelessManager.enabled

    Row {
      spacing: 8

      TitleText {
        text: WirelessManager.scanning ? "Scanning..."
          : settingsRoot.highlightText("Available Networks", settingsRoot.searchQuery)
        textFormat: Text.RichText
      }

      FocusIconButton {
        icon: "󰑐"
        visible: !WirelessManager.scanning
        enabled: !WirelessManager.busy
        opacity: enabled ? 1 : 0.5
        onClicked: WirelessManager.requestScan()
      }
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
          readonly property string statusText: {
            if (hasAction) return WirelessManager.actionMessage
            if (stateChanging) return "Updating…"
            if (known) return "Known network"
            return secured ? "Secured network" : "Open network"
          }

          width: parent.width
          spacing: 0
          visible: !connected

          Row {
            width: parent.width
            spacing: 12

            FocusListItem {
              width: parent.width - (availableForgetButton.visible
                ? availableForgetButton.width + parent.spacing : 0)
              icon: WirelessManager.getSignalIcon(networkDelegate.signal)
              iconColor: networkDelegate.hasAction ? Theme.accent : Theme.textMuted
              text: networkDelegate.ssid
              subtitle: networkDelegate.statusText
              subtitleColor: networkDelegate.hasAction ? Theme.accent : Theme.textMuted
              rightIcon: networkDelegate.secured ? "󰌾" : ""
              enabled: !WirelessManager.busy
              opacity: enabled ? 1 : 0.7
              onClicked: WirelessManager.connect(networkDelegate.networkKey)
            }

            FocusLink {
              id: availableForgetButton
              anchors.verticalCenter: parent.verticalCenter
              text: "Forget"
              visible: networkDelegate.known
              enabled: !WirelessManager.busy
              opacity: enabled ? 1 : 0.5
              onClicked: WirelessManager.forget(networkDelegate.networkKey)
            }
          }

          Column {
            width: parent.width
            spacing: 4
            visible: networkDelegate.isPending
            topPadding: 4

            onVisibleChanged: {
              if (visible) {
                settingsPasswordInput.clear()
                settingsPasswordInput.focusInput()
              }
            }

            Text {
              text: "Password required for " + networkDelegate.ssid
              color: Theme.textSecondary
              font.family: Theme.fontFamily
              font.pixelSize: Theme.scaledFontSize(12)
              leftPadding: 2
            }

            PasswordInput {
              id: settingsPasswordInput
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
        visible: settingsRoot.availableNetworkCount === 0
        topPadding: 8
      }
    }
  }

  Column {
    width: parent.width
    spacing: 8
    visible: !WirelessManager.enabled

    BodyText {
      text: !WirelessManager.backendAvailable ? "NetworkManager is unavailable"
        : !WirelessManager.hardwareEnabled ? "Wi-Fi hardware is disabled"
        : "Wi-Fi is off"
      topPadding: 16
    }

    BodyText {
      text: "Turn on Wi-Fi to connect to networks"
      visible: WirelessManager.backendAvailable && WirelessManager.hardwareEnabled
    }
  }
}
