pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: bluetoothManager

  // Bluetooth and BlueZ are the source of truth. Process completion never
  // changes these properties; native notifications update them instead.
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: adapter ? adapter.enabled : false
  readonly property bool scanning: adapter ? adapter.discovering : false

  readonly property var devices: {
    var result = []
    var nativeDevices = Bluetooth.devices.values
    for (var i = 0; i < nativeDevices.length; i++) {
      var device = nativeDevices[i]
      result.push({
        address: device.address,
        name: device.deviceName || device.name || device.address,
        paired: device.paired,
        bonded: device.bonded,
        trusted: device.trusted,
        connected: device.connected
      })
    }
    result.sort(function(a, b) {
      var aKnown = a.paired || a.bonded || a.trusted
      var bKnown = b.paired || b.bonded || b.trusted
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (aKnown !== bKnown) return aKnown ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    return result
  }

  readonly property var connectedDevices: devices.filter(function(device) {
    return device.connected
  })

  property alias powerPreference: powerConfig.powerPreference
  property bool busy: false
  property string connectingAddress: ""
  property string deviceAction: ""
  property string deviceActionAddress: ""
  property string connectError: ""
  property string connectErrorAddress: ""
  property string connectErrorAction: ""
  property string globalError: ""

  readonly property string deviceHelper:
    Quickshell.shellDir + "/modules/bluetooth/bin/bluetooth-device"

  property bool _scanRequested: false
  property bool _continuousScan: false
  property var _operations: []
  property var _activeOperation: null
  property bool _powerOnRequested: false
  property int _powerFallbackAttempts: 0
  readonly property int _maxPowerFallbackAttempts: 3
  property bool _powerPreferenceLoaded: false
  property bool _powerPreferenceRestored: false

  ModuleConfig {
    moduleId: "bluetooth"
    scope: "general"
    adapter: JsonAdapter {
      id: powerConfig
      property string powerPreference: ""
    }
    onLoaded: {
      bluetoothManager._powerPreferenceLoaded = true
      bluetoothManager._restorePowerPreference()
    }
  }

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  function clearErrors() {
    connectError = ""
    connectErrorAddress = ""
    connectErrorAction = ""
    globalError = ""
  }

  function togglePower() {
    if (busy) return
    if (powered) {
      powerPreference = "off"
      _powerOnRequested = false
      powerFallbackTimer.stop()
      _enqueueOperation("power-off", "", ["rfkill", "block", "bluetooth"])
    } else {
      if (_powerOnRequested) return
      powerPreference = "on"
      _powerOnRequested = true
      _powerFallbackAttempts = 0
      _enqueueOperation("power-on", "", ["rfkill", "unblock", "bluetooth"])
    }
  }

  function _restorePowerPreference() {
    if (_powerPreferenceRestored || !_powerPreferenceLoaded || !adapter
        || powerPreference === "") return
    _powerPreferenceRestored = true
    if ((powerPreference === "on") !== powered) togglePower()
  }

  // Continuous scans are used by transient surfaces. The default is a
  // bounded scan so existing callers cannot leave discovery enabled.
  function startScan(continuous = false) {
    // Preserve the request while the adapter is absent or powered off. The
    // enabled/adapter change handlers apply it when BlueZ becomes ready.
    _scanRequested = true
    _continuousScan = continuous === true
    if (_continuousScan) boundedScanTimer.stop()
    else boundedScanTimer.restart()
    _applyScanRequest()
  }

  function stopScan() {
    _scanRequested = false
    _continuousScan = false
    boundedScanTimer.stop()
    scanConfirmationTimer.stop()
    _setDiscovering(false)
  }

  function connect(address) {
    var device = _nativeDevice(address)
    var known = device && (device.paired || device.bonded || device.trusted)
    _enqueueDeviceOperation(known ? "connect" : "pair", address)
  }

  function disconnect(address) {
    _enqueueDeviceOperation("disconnect", address)
  }

  function forget(address) {
    _enqueueDeviceOperation("forget", address)
  }

  // =========================================================================
  // ICONS
  // =========================================================================

  readonly property string iconOff: "󰂲"
  readonly property string iconOn: "󰂰"
  readonly property string iconConnected: "󰂱"
  readonly property string iconScanning: "󰂯"

  function getIcon() {
    if (!powered) return iconOff
    if (connectedDevices.length > 0) return iconConnected
    if (scanning) return iconScanning
    return iconOn
  }

  // =========================================================================
  // OPERATION QUEUE
  // =========================================================================

  function _nativeDevice(address) {
    var nativeDevices = Bluetooth.devices.values
    for (var i = 0; i < nativeDevices.length; i++) {
      if (nativeDevices[i].address.toUpperCase() === address.toUpperCase())
        return nativeDevices[i]
    }
    return null
  }

  function _enqueueDeviceOperation(operation, address) {
    if (!address || busy) return
    connectError = ""
    connectErrorAddress = ""
    connectErrorAction = ""
    _enqueueOperation("device", address, [deviceHelper, operation, address], operation)
  }

  function _enqueueOperation(kind, address, command, action) {
    var pending = _operations.slice()
    pending.push({
      kind: kind,
      address: address,
      action: action || kind,
      command: command
    })
    _operations = pending
    busy = true
    _startNextOperation()
  }

  function _startNextOperation() {
    if (_activeOperation || operationProc.running) return
    if (_operations.length === 0) {
      busy = false
      connectingAddress = ""
      deviceAction = ""
      deviceActionAddress = ""
      return
    }

    var pending = _operations.slice()
    _activeOperation = pending.shift()
    _operations = pending
    deviceAction = _activeOperation.kind === "device" ? _activeOperation.action : ""
    deviceActionAddress = _activeOperation.kind === "device" ? _activeOperation.address : ""
    connectingAddress = deviceAction === "connect" || deviceAction === "pair"
      ? deviceActionAddress : ""
    operationProc.command = _activeOperation.command
    operationProc.running = true
  }

  function _errorMessage(operation, output) {
    var text = output.trim()
    var message = "Could not connect to this device."
    if (operation.action === "pair") message = "Could not pair with this device."
    else if (operation.action === "disconnect") message = "Could not disconnect this device."
    else if (operation.action === "forget") message = "Could not forget this device."
    return text ? message + " " + text : message
  }

  function _globalErrorMessage(operation, output) {
    var text = output.trim()
    var message = operation.action === "power-off"
      ? "Could not disable Bluetooth." : "Could not enable Bluetooth."
    return text ? message + " " + text : message
  }

  function _setDiscovering(discovering) {
    if (!adapter) return
    try {
      adapter.discovering = discovering
    } catch (error) {
      globalError = discovering ? "Could not start Bluetooth discovery."
        : "Could not stop Bluetooth discovery."
    }
  }

  function _applyScanRequest() {
    if (!_scanRequested || !adapter || !powered) return
    scanConfirmationTimer.restart()
    _setDiscovering(true)
  }

  function _schedulePowerFallback() {
    if (!_powerOnRequested || powered) return
    if (_powerFallbackAttempts < _maxPowerFallbackAttempts) {
      powerFallbackTimer.restart()
    } else {
      globalError = "Could not enable Bluetooth."
    }
  }

  Process {
    id: operationProc
    command: []
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      var operation = bluetoothManager._activeOperation
      if (!operation) return

      var output = (operationProc.stdout.text + "\n" + operationProc.stderr.text).trim()
      if (operation.kind === "device" && exitCode !== 0) {
        bluetoothManager.connectErrorAddress = operation.address
        bluetoothManager.connectErrorAction = operation.action
        bluetoothManager.connectError = bluetoothManager._errorMessage(operation, output)
      } else if (operation.kind !== "device" && exitCode !== 0) {
        var reachedRequestedState = operation.kind === "power-off"
          ? !bluetoothManager.powered : bluetoothManager.powered
        if (!reachedRequestedState)
          bluetoothManager.globalError = bluetoothManager._globalErrorMessage(operation, output)
      }

      if (operation.kind === "power-on" || operation.kind === "power-fallback") {
        if (bluetoothManager.powered) bluetoothManager.globalError = ""
        else bluetoothManager._schedulePowerFallback()
      }

      bluetoothManager._activeOperation = null
      bluetoothManager.connectingAddress = ""
      bluetoothManager.deviceAction = ""
      bluetoothManager.deviceActionAddress = ""
      bluetoothManager._startNextOperation()
    }
  }

  // rfkill normally enables the adapter. BlueZ can lag behind it, so retry a
  // direct power-on command after a delay, but never indefinitely.
  Timer {
    id: powerFallbackTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!bluetoothManager._powerOnRequested || bluetoothManager.powered
          || bluetoothManager._powerFallbackAttempts
            >= bluetoothManager._maxPowerFallbackAttempts) return
      bluetoothManager._powerFallbackAttempts++
      bluetoothManager._enqueueOperation("power-fallback", "",
        ["bluetoothctl", "power", "on"])
    }
  }

  Timer {
    id: boundedScanTimer
    interval: 10000
    repeat: false
    onTriggered: bluetoothManager.stopScan()
  }

  Timer {
    id: scanConfirmationTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (bluetoothManager._scanRequested && bluetoothManager.powered
          && !bluetoothManager.scanning)
        bluetoothManager.globalError = "Could not start Bluetooth discovery."
    }
  }

  // If a late BlueZ reply enables discovery after stopScan(), turn it back
  // off. This also covers a popup closing while scan startup is in flight.
  Connections {
    target: bluetoothManager.adapter
    ignoreUnknownSignals: true

    function onDiscoveringChanged() {
      if (!bluetoothManager.adapter) return
      if (bluetoothManager.adapter.discovering) {
        scanConfirmationTimer.stop()
        if (!bluetoothManager._scanRequested) {
          bluetoothManager._setDiscovering(false)
        } else {
          bluetoothManager.globalError = ""
        }
      } else if (bluetoothManager._scanRequested
          && bluetoothManager._continuousScan && bluetoothManager.powered) {
        // BlueZ may end discovery on its own. A transient surface's continuous
        // request remains authoritative until stopScan() is called.
        bluetoothManager._applyScanRequest()
      }
    }

    function onEnabledChanged() {
      if (!bluetoothManager.adapter) return
      if (bluetoothManager.adapter.enabled) {
        bluetoothManager._powerOnRequested = false
        bluetoothManager._powerFallbackAttempts = 0
        bluetoothManager.globalError = ""
        powerFallbackTimer.stop()
        bluetoothManager._applyScanRequest()
      }
    }
  }

  onAdapterChanged: {
    if (!adapter) return
    _restorePowerPreference()
    if (adapter.discovering && !_scanRequested) _setDiscovering(false)
    else _applyScanRequest()
  }
}
