pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Singleton {
  id: wirelessManager

  enum FailureCode {
    None,
    BackendUnavailable,
    WifiAuthTimeout,
    NoSecrets,
    WifiClientDisconnected,
    WifiNetworkLost,
    WifiClientFailed,
    Unknown,
    OperationTimeout
  }

  // Native, event-driven state. The public network model contains primitives
  // only; native WifiNetwork objects are resolved internally when needed.
  readonly property bool backendAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
  readonly property bool enabled: backendAvailable && Networking.wifiEnabled
  readonly property var networks: networkRows
  property var connectedNetwork: null
  property string activeDevice: ""

  readonly property bool busy: actionKind !== ""
  property string actionKind: "" // "radio" | "connect" | "disconnect" | "forget"
  property string actionKey: ""
  readonly property string actionMessage: {
    if (actionKind === "radio") return actionTargetEnabled ? "Enabling Wi-Fi…" : "Disabling Wi-Fi…"
    if (actionKind === "connect") return "Connecting…"
    if (actionKind === "disconnect") return "Disconnecting…"
    if (actionKind === "forget") return "Forgetting…"
    return ""
  }

  property int failureCode: WirelessManager.FailureCode.None
  property string failureKey: ""
  property string failureMessage: ""
  property string failureAction: ""
  property string pendingNetworkKey: ""

  // Popup scanning and bounded settings scans have independent ownership.
  property bool continuousScanRequested: false
  property bool boundedScanRequested: false
  readonly property bool scannerRequested: continuousScanRequested || boundedScanRequested
  property var scannerDevices: []
  readonly property bool scanning: scannerIsActive()

  // Passive interface throughput (bytes per second).
  property real downloadSpeed: 0
  property real uploadSpeed: 0
  property real lastRxBytes: 0
  property real lastTxBytes: 0
  property real lastSampleTime: 0

  // NetworkManager's last successful activation timestamp. Native Quickshell
  // does not expose it, so it is fetched once when the connection changes.
  property real connectionTimestamp: 0
  property int uptimeTick: 0
  property string uptimeNetworkKey: ""
  property bool uptimeRefreshPending: false

  property bool actionRequiresPsk: false
  property bool actionTargetEnabled: false

  readonly property var nativeDevices: Networking.devices ? Networking.devices.values : []
  readonly property string nativeRevision: buildNativeRevision()

  ListModel {
    id: networkRows
    dynamicRoles: false
  }

  function wifiDevices() {
    var result = []
    var devices = nativeDevices || []
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (device && device.type === DeviceType.Wifi) result.push(device)
    }
    return result
  }

  function networkKey(device, network) {
    return JSON.stringify([device.name || "", network.name || ""])
  }

  function buildNativeRevision() {
    var parts = [Networking.backend, Networking.wifiEnabled, Networking.wifiHardwareEnabled]
    var devices = nativeDevices || []
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device) continue
      parts.push(device.type, device.name, device.connected, device.state)
      if (device.type !== DeviceType.Wifi || !device.networks) continue

      var available = device.networks.values || []
      parts.push(available.length)
      for (var j = 0; j < available.length; j++) {
        var network = available[j]
        if (!network) continue
        parts.push(network.name, network.signalStrength, network.security, network.known,
                   network.connected, network.state, network.stateChanging)
      }
    }
    return parts.join("\u001f")
  }

  function isPskSecurity(security) {
    return security === WifiSecurityType.WpaPsk
        || security === WifiSecurityType.Wpa2Psk
        || security === WifiSecurityType.Sae
  }

  function primitiveRow(device, network) {
    var security = network.security
    return {
      networkKey: networkKey(device, network),
      deviceName: device.name || "",
      ssid: network.name || "",
      signal: Math.round(Math.max(0, Math.min(1, network.signalStrength || 0)) * 100),
      security: security,
      secured: security !== WifiSecurityType.Open,
      requiresPsk: isPskSecurity(security),
      known: !!network.known,
      connected: !!network.connected,
      state: network.state,
      stateChanging: !!network.stateChanging
    }
  }

  function copyRow(row) {
    return {
      networkKey: row.networkKey,
      deviceName: row.deviceName,
      ssid: row.ssid,
      signal: row.signal,
      security: row.security,
      secured: row.secured,
      requiresPsk: row.requiresPsk,
      known: row.known,
      connected: row.connected,
      state: row.state,
      stateChanging: row.stateChanging
    }
  }

  function sortRows(rows) {
    rows.sort(function(a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.signal !== b.signal) return b.signal - a.signal
      var ssidOrder = a.ssid.localeCompare(b.ssid)
      if (ssidOrder !== 0) return ssidOrder
      return a.deviceName.localeCompare(b.deviceName)
    })
    return rows
  }

  function rowIndex(key, start) {
    for (var i = start || 0; i < networkRows.count; i++) {
      if (networkRows.get(i).networkKey === key) return i
    }
    return -1
  }

  function updateRows(rows) {
    var wanted = {}
    for (var i = 0; i < rows.length; i++) wanted[rows[i].networkKey] = true

    for (var oldIndex = networkRows.count - 1; oldIndex >= 0; oldIndex--) {
      if (!wanted[networkRows.get(oldIndex).networkKey]) networkRows.remove(oldIndex)
    }

    var roles = ["networkKey", "deviceName", "ssid", "signal", "security", "secured",
                 "requiresPsk", "known", "connected", "state", "stateChanging"]
    for (var target = 0; target < rows.length; target++) {
      var source = rowIndex(rows[target].networkKey, target)
      if (source < 0) networkRows.insert(target, rows[target])
      else if (source !== target) networkRows.move(source, target, 1)

      for (var roleIndex = 0; roleIndex < roles.length; roleIndex++) {
        var role = roles[roleIndex]
        networkRows.setProperty(target, role, rows[target][role])
      }
    }
  }

  function syncNativeState() {
    var rows = []
    var connected = null
    var connectedDevice = ""
    var devices = wifiDevices()

    if (backendAvailable && enabled) {
      for (var i = 0; i < devices.length; i++) {
        var device = devices[i]
        var available = device.networks ? device.networks.values : []
        for (var j = 0; j < available.length; j++) {
          var network = available[j]
          if (!network || !network.name) continue
          var row = primitiveRow(device, network)
          rows.push(row)
          if (!connected && row.connected) {
            connected = copyRow(row)
            connectedDevice = row.deviceName
          }
        }
      }
    }

    sortRows(rows)
    updateRows(rows)
    connectedNetwork = connected
    activeDevice = connectedDevice
    syncConnectionUptime(connected)
    applyScannerState()
    reconcileAction()
  }

  function resolveNetwork(key) {
    if (!key) return null
    var devices = wifiDevices()
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      var available = device.networks ? device.networks.values : []
      for (var j = 0; j < available.length; j++) {
        var network = available[j]
        if (network && networkKey(device, network) === key) return network
      }
    }
    return null
  }

  function clearFailure() {
    failureCode = WirelessManager.FailureCode.None
    failureKey = ""
    failureMessage = ""
    failureAction = ""
  }

  function setFailure(code, key, message, action) {
    failureCode = code
    failureKey = key || ""
    failureMessage = message
    failureAction = action || ""
  }

  function backendFailure(action, key) {
    setFailure(WirelessManager.FailureCode.BackendUnavailable, key,
               "NetworkManager is unavailable.", action)
  }

  function beginAction(kind, key, network) {
    if (busy) return false
    if (!backendAvailable) {
      backendFailure(kind, key)
      return false
    }

    clearFailure()
    actionKind = kind
    actionKey = key || ""
    actionRequiresPsk = !!network && isPskSecurity(network.security)
    actionTimeout.restart()
    return true
  }

  function finishAction() {
    var finishedKind = actionKind
    actionTimeout.stop()
    actionKind = ""
    actionKey = ""
    actionRequiresPsk = false
    if (finishedKind === "connect") pendingNetworkKey = ""
  }

  function failAction(code, message) {
    var failedKind = actionKind
    var failedKey = actionKey
    actionTimeout.stop()
    actionKind = ""
    actionKey = ""
    actionRequiresPsk = false
    setFailure(code, failedKey, message, failedKind)
  }

  function reconcileAction() {
    if (!busy) return
    if (!backendAvailable) {
      failAction(WirelessManager.FailureCode.BackendUnavailable,
                 "NetworkManager became unavailable.")
      return
    }

    if (actionKind === "radio") {
      if (Networking.wifiEnabled === actionTargetEnabled) finishAction()
      return
    }

    var network = resolveNetwork(actionKey)
    if (!network) {
      if (actionKind === "disconnect" || actionKind === "forget") finishAction()
      return
    }
    if (actionKind === "connect" && network.connected) finishAction()
    else if (actionKind === "disconnect" && !network.connected && !network.stateChanging) finishAction()
    else if (actionKind === "forget" && !network.known && !network.stateChanging) finishAction()
  }

  function failureFromReason(reason) {
    if (reason === ConnectionFailReason.WifiAuthTimeout)
      return WirelessManager.FailureCode.WifiAuthTimeout
    if (reason === ConnectionFailReason.NoSecrets)
      return WirelessManager.FailureCode.NoSecrets
    if (reason === ConnectionFailReason.WifiClientDisconnected)
      return WirelessManager.FailureCode.WifiClientDisconnected
    if (reason === ConnectionFailReason.WifiNetworkLost)
      return WirelessManager.FailureCode.WifiNetworkLost
    if (reason === ConnectionFailReason.WifiClientFailed)
      return WirelessManager.FailureCode.WifiClientFailed
    if (reason === ConnectionFailReason.Unknown)
      return WirelessManager.FailureCode.Unknown
    return WirelessManager.FailureCode.Unknown
  }

  function messageForFailure(reason, requiresPsk) {
    if (reason === ConnectionFailReason.WifiAuthTimeout)
      return requiresPsk ? "Wrong password." : "Wi-Fi authentication timed out."
    if (reason === ConnectionFailReason.NoSecrets)
      return requiresPsk ? "Password required." : "Credentials required."
    if (reason === ConnectionFailReason.WifiClientDisconnected) return "Wi-Fi client disconnected."
    if (reason === ConnectionFailReason.WifiNetworkLost) return "Network lost."
    if (reason === ConnectionFailReason.WifiClientFailed) return "Wi-Fi client failed."
    if (reason === ConnectionFailReason.Unknown) return "Connection failed."
    return "Connection failed."
  }

  function handleConnectionFailure(reason) {
    if (actionKind !== "connect") return
    var key = actionKey
    var reprompt = actionRequiresPsk
        && (reason === ConnectionFailReason.NoSecrets
            || reason === ConnectionFailReason.WifiAuthTimeout)
    failAction(failureFromReason(reason), messageForFailure(reason, actionRequiresPsk))
    if (reprompt) pendingNetworkKey = key
  }

  function setEnabled(value) {
    value = !!value
    if (!backendAvailable) {
      backendFailure("radio", "")
      return false
    }
    if (busy || Networking.wifiEnabled === value) return false
    actionTargetEnabled = value
    if (!beginAction("radio", "", null)) return false
    Networking.wifiEnabled = value
    reconcileAction()
    return true
  }

  function toggleEnabled() {
    return setEnabled(!enabled)
  }

  function connect(key) {
    if (busy) return false
    if (!backendAvailable) {
      backendFailure("connect", key)
      return false
    }
    var network = resolveNetwork(key)
    if (!network) {
      setFailure(WirelessManager.FailureCode.Unknown, key,
                 "Network is no longer available.", "connect")
      return false
    }
    if (isPskSecurity(network.security) && !network.known) {
      clearFailure()
      pendingNetworkKey = key
      return true
    }
    pendingNetworkKey = ""
    if (!beginAction("connect", key, network)) return false
    try {
      network.connect()
      reconcileAction()
      return true
    } catch (error) {
      failAction(WirelessManager.FailureCode.Unknown, "Could not start connection.")
      return false
    }
  }

  function connectWithPsk(key, password) {
    if (busy) return false
    if (!backendAvailable) {
      backendFailure("connect", key)
      return false
    }
    var network = resolveNetwork(key)
    if (!network) {
      setFailure(WirelessManager.FailureCode.Unknown, key,
                 "Network is no longer available.", "connect")
      return false
    }
    if (!isPskSecurity(network.security)) return connect(key)
    pendingNetworkKey = ""
    if (!beginAction("connect", key, network)) return false
    try {
      // The password is passed directly to the native backend and never stored.
      network.connectWithPsk(password)
      reconcileAction()
      return true
    } catch (error) {
      failAction(WirelessManager.FailureCode.Unknown, "Could not start connection.")
      return false
    }
  }

  function disconnect(key) {
    if (busy) return false
    if (!backendAvailable) {
      backendFailure("disconnect", key)
      return false
    }
    var network = resolveNetwork(key)
    if (!network) {
      setFailure(WirelessManager.FailureCode.Unknown, key,
                 "Network is no longer available.", "disconnect")
      return false
    }
    if (!beginAction("disconnect", key, network)) return false
    try {
      network.disconnect()
      reconcileAction()
      return true
    } catch (error) {
      failAction(WirelessManager.FailureCode.Unknown, "Could not disconnect network.")
      return false
    }
  }

  function forget(key) {
    if (busy) return false
    if (!backendAvailable) {
      backendFailure("forget", key)
      return false
    }
    var network = resolveNetwork(key)
    if (!network) {
      setFailure(WirelessManager.FailureCode.Unknown, key,
                 "Network is no longer available.", "forget")
      return false
    }
    if (!beginAction("forget", key, network)) return false
    try {
      network.forget()
      reconcileAction()
      return true
    } catch (error) {
      failAction(WirelessManager.FailureCode.Unknown, "Could not forget network.")
      return false
    }
  }

  function cancelPending() {
    pendingNetworkKey = ""
    clearFailure()
  }

  function scannerIsActive() {
    if (!scannerRequested || !enabled || scannerDevices.length === 0) return false
    for (var i = 0; i < scannerDevices.length; i++) {
      if (scannerDevices[i] && scannerDevices[i].scannerEnabled) return true
    }
    return false
  }

  function startScanning() {
    continuousScanRequested = true
    applyScannerState()
  }

  function stopScanning() {
    continuousScanRequested = false
    applyScannerState()
  }

  function requestScan() {
    boundedScanRequested = true
    scannerStopTimer.restart()
    applyScannerState()
  }

  function applyScannerState() {
    var devices = enabled && scannerRequested ? wifiDevices() : []
    var previous = scannerDevices || []

    for (var i = 0; i < previous.length; i++) {
      if (devices.indexOf(previous[i]) < 0) previous[i].scannerEnabled = false
    }
    for (var j = 0; j < devices.length; j++) devices[j].scannerEnabled = true
    scannerDevices = devices.slice()
  }

  function releaseScanners() {
    var previous = scannerDevices || []
    for (var i = 0; i < previous.length; i++) previous[i].scannerEnabled = false
    scannerDevices = []
  }

  readonly property string iconDisabled: "󰤮"
  readonly property string iconDisconnected: "󰤯"
  readonly property var iconSignal: ["󰤟", "󰤢", "󰤥", "󰤨"]

  function getIcon() {
    if (!enabled) return iconDisabled
    if (!connectedNetwork) return iconDisconnected
    return getSignalIcon(connectedNetwork.signal || 0)
  }

  function getSignalIcon(signal) {
    if (signal >= 75) return iconSignal[3]
    if (signal >= 50) return iconSignal[2]
    if (signal >= 25) return iconSignal[1]
    return iconSignal[0]
  }

  function formatSpeed(bytesPerSecond) {
    if (bytesPerSecond < 1024) return bytesPerSecond.toFixed(0) + " B/s"
    if (bytesPerSecond < 1024 * 1024) return (bytesPerSecond / 1024).toFixed(1) + " KB/s"
    return (bytesPerSecond / (1024 * 1024)).toFixed(2) + " MB/s"
  }

  function syncConnectionUptime(network) {
    var key = network ? network.networkKey : ""
    if (key === uptimeNetworkKey) return

    uptimeNetworkKey = key
    connectionTimestamp = 0
    uptimeTick = 0
    if (!network) return

    if (connectionUuidProc.running || connectionTimestampProc.running) {
      uptimeRefreshPending = true
      return
    }

    connectionUuidProc.sampleKey = key
    connectionUuidProc.command = ["nmcli", "-g", "GENERAL.CON-UUID", "device", "show", network.deviceName]
    connectionUuidProc.running = true
  }

  function finishUptimeLookup() {
    if (!uptimeRefreshPending) return
    uptimeRefreshPending = false
    var network = connectedNetwork
    uptimeNetworkKey = ""
    syncConnectionUptime(network)
  }

  function formatDurationLong(seconds) {
    if (seconds < 60) return "Less than a minute"
    var minutes = Math.floor(seconds / 60) % 60
    var hours = Math.floor(seconds / 3600) % 24
    var days = Math.floor(seconds / 86400)
    var parts = []
    if (days > 0) parts.push(days + (days === 1 ? " day" : " days"))
    if (hours > 0) parts.push(hours + (hours === 1 ? " hour" : " hours"))
    if (minutes > 0) parts.push(minutes + (minutes === 1 ? " min" : " mins"))
    return parts.join(", ")
  }

  function getConnectionDurationLong() {
    var _ = uptimeTick
    if (connectionTimestamp <= 0) return ""
    return formatDurationLong(Math.max(0, Math.floor(Date.now() / 1000) - connectionTimestamp))
  }

  function resetThroughput() {
    downloadSpeed = 0
    uploadSpeed = 0
    lastRxBytes = 0
    lastTxBytes = 0
    lastSampleTime = 0
  }

  function pollThroughput() {
    if (!activeDevice || networkStatsProc.running) return
    networkStatsProc.sampleDevice = activeDevice
    networkStatsProc.running = true
  }

  onNativeRevisionChanged: syncNativeState()
  onActiveDeviceChanged: resetThroughput()
  onEnabledChanged: {
    if (!enabled) pendingNetworkKey = ""
    applyScannerState()
    reconcileAction()
  }
  Component.onCompleted: syncNativeState()
  Component.onDestruction: releaseScanners()

  Connections {
    target: wirelessManager.resolveNetwork(wirelessManager.actionKey)

    function onConnectedChanged() {
      wirelessManager.syncNativeState()
    }

    function onKnownChanged() {
      wirelessManager.syncNativeState()
    }

    function onStateChangingChanged() {
      wirelessManager.syncNativeState()
    }

    function onConnectionFailed(reason) {
      wirelessManager.handleConnectionFailure(reason)
    }
  }

  Timer {
    id: actionTimeout
    interval: 30000
    repeat: false
    onTriggered: {
      if (!wirelessManager.busy) return
      var kind = wirelessManager.actionKind
      var message = kind === "connect" ? "Timed out connecting."
                  : kind === "disconnect" ? "Timed out disconnecting."
                  : kind === "forget" ? "Timed out forgetting."
                  : "Timed out changing Wi-Fi radio state."
      wirelessManager.failAction(WirelessManager.FailureCode.OperationTimeout, message)
    }
  }

  Timer {
    id: scannerStopTimer
    interval: 5000
    repeat: false
    onTriggered: {
      wirelessManager.boundedScanRequested = false
      wirelessManager.applyScannerState()
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: wirelessManager.connectionTimestamp > 0
    onTriggered: wirelessManager.uptimeTick++
  }

  Process {
    id: connectionUuidProc
    property string sampleKey: ""
    command: []
    stdout: StdioCollector { id: uuidOutput }
    onExited: function(exitCode) {
      if (sampleKey !== wirelessManager.uptimeNetworkKey) {
        wirelessManager.finishUptimeLookup()
        return
      }

      var uuid = uuidOutput.text.trim()
      if (exitCode !== 0 || !uuid) {
        wirelessManager.finishUptimeLookup()
        return
      }

      connectionTimestampProc.sampleKey = sampleKey
      connectionTimestampProc.command = ["nmcli", "-g", "connection.timestamp",
                                         "connection", "show", "uuid", uuid]
      connectionTimestampProc.running = true
    }
  }

  Process {
    id: connectionTimestampProc
    property string sampleKey: ""
    command: []
    stdout: StdioCollector { id: timestampOutput }
    onExited: function(exitCode) {
      if (sampleKey === wirelessManager.uptimeNetworkKey && exitCode === 0)
        wirelessManager.connectionTimestamp = parseInt(timestampOutput.text.trim()) || 0
      wirelessManager.finishUptimeLookup()
    }
  }

  Process {
    id: networkStatsProc
    property string sampleDevice: ""
    command: sampleDevice ? [
      "cat",
      "/sys/class/net/" + sampleDevice + "/statistics/rx_bytes",
      "/sys/class/net/" + sampleDevice + "/statistics/tx_bytes"
    ] : []
    stdout: StdioCollector { id: statsOutput }
    onExited: {
      if (sampleDevice !== wirelessManager.activeDevice) return
      var lines = statsOutput.text.trim().split("\n")
      if (lines.length < 2) return

      var rxBytes = parseInt(lines[0])
      var txBytes = parseInt(lines[1])
      if (!isFinite(rxBytes) || !isFinite(txBytes)) return
      var now = Date.now()
      if (wirelessManager.lastSampleTime > 0 && now > wirelessManager.lastSampleTime) {
        var elapsed = (now - wirelessManager.lastSampleTime) / 1000
        wirelessManager.downloadSpeed = Math.max(0, rxBytes - wirelessManager.lastRxBytes) / elapsed
        wirelessManager.uploadSpeed = Math.max(0, txBytes - wirelessManager.lastTxBytes) / elapsed
      }
      wirelessManager.lastRxBytes = rxBytes
      wirelessManager.lastTxBytes = txBytes
      wirelessManager.lastSampleTime = now
    }
  }

  Timer {
    interval: 1000
    running: wirelessManager.enabled && wirelessManager.connectedNetwork !== null
             && wirelessManager.activeDevice !== ""
    repeat: true
    onTriggered: wirelessManager.pollThroughput()
  }
}
