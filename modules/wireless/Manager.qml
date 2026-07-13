pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: wirelessManager

  // =========================================================================
  // PUBLIC STATE
  // =========================================================================

  // WiFi radio enabled
  property bool enabled: false

  // Currently scanning
  property bool scanning: false

  // Connected network (null if none)
  property var connectedNetwork: null

  // Connection timestamp (Unix timestamp when connected)
  property int connectionTimestamp: 0

  // List of available networks
  // Each: { ssid: string, signal: int, security: string, active: bool }
  property var networks: []

  // Operation in progress
  property bool busy: false

  // SSID currently being connected to (for UI feedback)
  property string connectingSSID: ""

  // Suppress refreshes briefly after operations
  property bool suppressRefresh: false

  // Saved WiFi connection profiles (SSIDs with stored credentials)
  property var savedConnections: []

  // SSID awaiting password entry (non-empty triggers password prompt in UI)
  property string pendingSSID: ""

  // Error message from last failed connection attempt
  property string connectError: ""

  // Active NetworkManager Wi-Fi device (predictable names vary by system).
  property string activeDevice: ""
  property bool disconnectPending: false

  // Network speeds (bytes per second)
  property real downloadSpeed: 0
  property real uploadSpeed: 0
  property real lastRxBytes: 0
  property real lastTxBytes: 0

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  function toggleEnabled() {
    if (enabled) {
      // Optimistic update
      enabled = false
      connectedNetwork = null
      networks = []
      disableProc.running = true
    } else {
      // Optimistic update
      enabled = true
      enableProc.running = true
    }
  }

  function startScan() {
    if (!enabled || scanning) return
    scanning = true
    scanProc.running = true
  }

  function connect(ssid, password) {
    connectError = ""

    // If the network is secured and has no saved profile, prompt for password
    if (!password) {
      var network = null
      for (var i = 0; i < networks.length; i++) {
        if (networks[i].ssid === ssid) {
          network = networks[i]
          break
        }
      }

      var hasSavedProfile = savedConnections.indexOf(ssid) >= 0
      if (network && network.security && !hasSavedProfile) {
        pendingSSID = ssid
        return
      }
    }

    pendingSSID = ""
    busy = true
    connectingSSID = ssid
    connectProc.lastSSID = ssid
    if (password) {
      connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
    } else {
      connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
    }
    connectProc.running = true
  }

  function cancelPending() {
    pendingSSID = ""
    connectError = ""
  }

  function disconnect() {
    if (!activeDevice) {
      disconnectPending = true
      activeDeviceProc.running = true
      return
    }
    disconnectPending = false
    busy = true
    suppressRefresh = true
    disconnectProc.command = ["nmcli", "dev", "disconnect", activeDevice]
    // Optimistic update
    connectedNetwork = null
    var updatedNetworks = networks.slice()
    for (var i = 0; i < updatedNetworks.length; i++) {
      updatedNetworks[i].active = false
    }
    networks = updatedNetworks
    disconnectProc.running = true
  }

  function refresh() {
    statusProc.running = true
  }

  // =========================================================================
  // ICONS
  // =========================================================================

  readonly property string iconDisabled: "󰤮"
  readonly property string iconDisconnected: "󰤯"
  readonly property var iconSignal: ["󰤟", "󰤢", "󰤥", "󰤨"]

  function getIcon() {
    if (!enabled) return iconDisabled
    if (!connectedNetwork) return iconDisconnected
    var signal = connectedNetwork.signal || 0
    if (signal >= 75) return iconSignal[3]
    if (signal >= 50) return iconSignal[2]
    if (signal >= 25) return iconSignal[1]
    return iconSignal[0]
  }

  function getSignalIcon(signal) {
    if (signal >= 75) return iconSignal[3]
    if (signal >= 50) return iconSignal[2]
    if (signal >= 25) return iconSignal[1]
    return iconSignal[0]
  }

  function formatDuration(seconds) {
    if (seconds < 60) return "Just now"
    var minutes = Math.floor(seconds / 60)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)

    if (days > 0) {
      hours = hours % 24
      return days + "d " + hours + "h"
    }
    if (hours > 0) {
      minutes = minutes % 60
      return hours + "h " + minutes + "m"
    }
    return minutes + "m"
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

  function getConnectionDuration() {
    if (connectionTimestamp <= 0) return ""
    var now = Math.floor(Date.now() / 1000)
    var seconds = now - connectionTimestamp
    return formatDuration(seconds)
  }

  function getConnectionDurationLong() {
    if (connectionTimestamp <= 0) return ""
    var now = Math.floor(Date.now() / 1000)
    var seconds = now - connectionTimestamp
    return formatDurationLong(seconds)
  }

  function formatSpeed(bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return bytesPerSecond.toFixed(0) + " B/s"
    } else if (bytesPerSecond < 1024 * 1024) {
      return (bytesPerSecond / 1024).toFixed(1) + " KB/s"
    } else {
      return (bytesPerSecond / (1024 * 1024)).toFixed(2) + " MB/s"
    }
  }

  // =========================================================================
  // PROCESSES
  // =========================================================================

  // Check WiFi status
  Process {
    id: statusProc
    command: ["nmcli", "-t", "radio", "wifi"]
    running: true
    stdout: StdioCollector {}
    onExited: {
      wirelessManager.enabled = statusProc.stdout.text.trim() === "enabled"
      if (wirelessManager.enabled) {
        activeDeviceProc.running = true
        networkListProc.running = true
        savedConnectionsProc.running = true
      } else {
        wirelessManager.activeDevice = ""
        wirelessManager.connectedNetwork = null
        wirelessManager.networks = []
      }
    }
  }

  // Enable WiFi
  Process {
    id: enableProc
    command: ["nmcli", "radio", "wifi", "on"]
    onExited: {
      enableScanTimer.restart()
    }
  }

  Timer {
    id: enableScanTimer
    interval: 1000
    onTriggered: {
      wirelessManager.scanning = true
      scanProc.running = true
    }
  }

  // Disable WiFi
  Process {
    id: disableProc
    command: ["nmcli", "radio", "wifi", "off"]
    onExited: {
      wirelessManager.enabled = false
      wirelessManager.connectedNetwork = null
      wirelessManager.networks = []
    }
  }

  // Scan for networks (with rescan)
  Process {
    id: scanProc
    command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
    stdout: StdioCollector {}
    onExited: {
      wirelessManager.scanning = false
      wirelessManager.parseNetworkList(scanProc.stdout.text)
    }
  }

  // Get network list (without rescan)
  Process {
    id: networkListProc
    command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
    stdout: StdioCollector {}
    onExited: {
      wirelessManager.parseNetworkList(networkListProc.stdout.text)
      // Fetch connection timestamp if connected
      if (wirelessManager.connectedNetwork) {
        timestampProc.running = true
      }
    }
  }

  // Get connection timestamp
  Process {
    id: timestampProc
    command: ["nmcli", "-t", "-f", "NAME,TIMESTAMP", "connection", "show", "--active"]
    stdout: StdioCollector {}
    onExited: {
      var lines = timestampProc.stdout.text.trim().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split(":")
        if (parts.length >= 2 && wirelessManager.connectedNetwork && parts[0] === wirelessManager.connectedNetwork.ssid) {
          wirelessManager.connectionTimestamp = parseInt(parts[1]) || 0
          return
        }
      }
      wirelessManager.connectionTimestamp = 0
    }
  }

  // Fetch saved WiFi connection profiles
  Process {
    id: savedConnectionsProc
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
    stdout: StdioCollector {}
    onExited: {
      var lines = savedConnectionsProc.stdout.text.trim().split("\n")
      var saved = []
      var suffix = ":802-11-wireless"
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (line.length > suffix.length && line.slice(-suffix.length) === suffix) {
          saved.push(line.slice(0, -suffix.length))
        }
      }
      wirelessManager.savedConnections = saved
    }
  }

  // Connect to network
  Process {
    id: connectProc
    property string lastSSID: ""
    command: []
    stderr: StdioCollector {}
    onExited: exitCode => {
      wirelessManager.busy = false
      wirelessManager.connectingSSID = ""
      if (exitCode !== 0) {
        var errMsg = connectProc.stderr.text.trim()
        // Find the network to check if it's secured
        var network = null
        for (var i = 0; i < wirelessManager.networks.length; i++) {
          if (wirelessManager.networks[i].ssid === lastSSID) {
            network = wirelessManager.networks[i]
            break
          }
        }
        // Re-show password prompt if the network is secured
        if (network && network.security) {
          wirelessManager.pendingSSID = lastSSID
        }
        // Use nmcli's actual error when available
        if (errMsg) {
          // Strip "Error: " prefix from nmcli output
          if (errMsg.indexOf("Error: ") === 0) {
            errMsg = errMsg.substring(7)
          }
          wirelessManager.connectError = errMsg
        } else {
          wirelessManager.connectError = "Connection failed."
        }
      } else {
        wirelessManager.connectError = ""
        wirelessManager.pendingSSID = ""
        savedConnectionsProc.running = true
      }
      wirelessManager.refresh()
    }
  }

  // Resolve the active Wi-Fi interface rather than assuming wlan0.
  Process {
    id: activeDeviceProc
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device", "status"]
    stdout: StdioCollector {}
    onExited: {
      var lines = stdout.text.trim().split("\n")
      wirelessManager.activeDevice = ""
      for (var i = 0; i < lines.length; i++) {
        var fields = lines[i].split(":")
        if (fields.length >= 2 && fields[1] === "wifi") {
          wirelessManager.activeDevice = fields[0]
          break
        }
      }
      if (wirelessManager.disconnectPending && wirelessManager.activeDevice) {
        wirelessManager.disconnect()
      }
    }
  }

  // Disconnect
  Process {
    id: disconnectProc
    command: []
    onExited: {
      wirelessManager.busy = false
      disconnectRefreshTimer.restart()
    }
  }

  Timer {
    id: disconnectRefreshTimer
    interval: 1000
    onTriggered: {
      wirelessManager.suppressRefresh = false
      wirelessManager.refresh()
    }
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  function parseNetworkList(output) {
    var lines = output.trim().split("\n").filter(function(l) { return l.length > 0 })
    var networksBySsid = {}
    var connected = null

    for (var i = 0; i < lines.length; i++) {
      // Format: ACTIVE:SSID:SIGNAL:SECURITY
      var parts = lines[i].split(":")
      if (parts.length >= 4) {
        var active = parts[0] === "yes"
        var ssid = parts[1]
        var signal = parseInt(parts[2]) || 0
        var security = parts.slice(3).join(":") // Security may contain colons

        // Skip empty SSIDs
        if (!ssid) continue

        var network = {
          ssid: ssid,
          signal: signal,
          security: security,
          active: active
        }

        // If we've seen this SSID, keep the one with active=true or stronger signal
        if (networksBySsid[ssid]) {
          if (active) {
            networksBySsid[ssid] = network
          } else if (!networksBySsid[ssid].active && signal > networksBySsid[ssid].signal) {
            networksBySsid[ssid] = network
          }
        } else {
          networksBySsid[ssid] = network
        }

        if (active) {
          connected = network
        }
      }
    }

    // Convert to array
    var newNetworks = []
    for (var ssidKey in networksBySsid) {
      newNetworks.push(networksBySsid[ssidKey])
    }

    // Sort by signal strength (strongest first), but keep active at top
    newNetworks.sort(function(a, b) {
      if (a.active && !b.active) return -1
      if (!a.active && b.active) return 1
      return b.signal - a.signal
    })

    wirelessManager.networks = newNetworks
    wirelessManager.connectedNetwork = connected
  }

  // =========================================================================
  // NETWORK SPEED TRACKING
  // =========================================================================

  Process {
    id: networkStatsProc
    command: wirelessManager.activeDevice ? [
      "cat",
      "/sys/class/net/" + wirelessManager.activeDevice + "/statistics/rx_bytes",
      "/sys/class/net/" + wirelessManager.activeDevice + "/statistics/tx_bytes"
    ] : []
    stdout: StdioCollector {}
    onExited: {
      var lines = networkStatsProc.stdout.text.trim().split("\n")
      if (lines.length >= 2) {
        var rxBytes = parseInt(lines[0]) || 0
        var txBytes = parseInt(lines[1]) || 0

        if (wirelessManager.lastRxBytes > 0) {
          wirelessManager.downloadSpeed = rxBytes - wirelessManager.lastRxBytes
          wirelessManager.uploadSpeed = txBytes - wirelessManager.lastTxBytes
        }

        wirelessManager.lastRxBytes = rxBytes
        wirelessManager.lastTxBytes = txBytes
      }
    }
  }

  Timer {
    interval: 1000
    running: wirelessManager.enabled && wirelessManager.connectedNetwork && wirelessManager.activeDevice
    repeat: true
    onTriggered: networkStatsProc.running = true
  }

  // =========================================================================
  // TIMERS
  // =========================================================================

  // Periodic refresh
  Timer {
    interval: 30000
    running: wirelessManager.enabled && !wirelessManager.suppressRefresh
    repeat: true
    onTriggered: networkListProc.running = true
  }
}
