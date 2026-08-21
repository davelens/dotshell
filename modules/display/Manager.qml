pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: displayManager

  property var outputs: []
  property string selectedOutputName: ""
  readonly property var selectedOutput: outputByName(selectedOutputName)
  property bool lidStateKnown: false
  property bool lidClosed: false
  property bool _outputPowerPending: false
  property string _pendingOutputName: ""
  property bool _pendingOutputAutomatic: false
  property string _clamshellOutputName: ""
  property bool _automaticRetryAttempted: false
  readonly property int activeCount: {
    var count = 0
    for (var i = 0; i < outputs.length; i++) if (outputs[i].active) count++
    return count
  }

  property int selectedBrightness: 50
  property bool brightnessAvailable: false
  property int _brightnessGeneration: 0
  property bool _brightnessReadPending: false
  property bool _brightnessWritePending: false
  property string _pendingBrightnessConnector: ""
  property int _pendingBrightnessValue: 50

  readonly property var scalePresets: [1, 1.25, 1.33, 1.6, 2, 3]
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
  readonly property int textSize: Math.max(9, Math.min(20, config.textSize))
  property int _textProcessValue: -1

  readonly property string brightnessCommand:
    Quickshell.shellDir + "/modules/display/bin/display-brightness"
  readonly property string textSizeCommand:
    Quickshell.shellDir + "/modules/display/bin/display-text-size"

  ModuleConfig {
    moduleId: "display"
    scope: "general"
    adapter: JsonAdapter {
      id: config
      property int textSize: 14
    }
  }

  Binding {
    target: Theme
    property: "fontScale"
    value: displayManager.textSize / 14
  }

  function outputByName(name) {
    for (var i = 0; i < outputs.length; i++) {
      if (outputs[i].name === name) return outputs[i]
    }
    return null
  }

  function _modeForNiri(output) {
    if (output.current_mode === null || output.current_mode === undefined) return null
    if (typeof output.current_mode === "object") return output.current_mode
    return output.modes && output.modes[output.current_mode]
      ? output.modes[output.current_mode] : null
  }

  function normalizeOutputs(json) {
    var raw
    try {
      raw = JSON.parse(json)
    } catch (e) {
      console.error("[DisplayManager] Failed to parse outputs:", e)
      return []
    }

    var normalized = []
    if (Array.isArray(raw)) {
      for (var i = 0; i < raw.length; i++) {
        var sway = raw[i]
        var swayMode = sway.current_mode || null
        normalized.push({
          name: sway.name,
          active: !!sway.active,
          scale: Number(sway.scale) || 1,
          mode: swayMode,
          width: swayMode ? swayMode.width : 0,
          height: swayMode ? swayMode.height : 0,
          x: sway.rect ? sway.rect.x : 0,
          y: sway.rect ? sway.rect.y : 0,
          make: sway.make || "",
          model: sway.model || "",
          serial: sway.serial || "",
          workspace: sway.current_workspace || ""
        })
      }
    } else if (raw && typeof raw === "object") {
      var names = Object.keys(raw)
      for (var j = 0; j < names.length; j++) {
        var name = names[j]
        var niri = raw[name] || {}
        var niriMode = _modeForNiri(niri)
        var logical = niri.logical || null
        normalized.push({
          name: niri.name || name,
          active: logical !== null,
          scale: logical && Number(logical.scale) ? Number(logical.scale) : 1,
          mode: niriMode,
          width: niriMode ? niriMode.width : 0,
          height: niriMode ? niriMode.height : 0,
          x: logical ? logical.x : 0,
          y: logical ? logical.y : 0,
          make: niri.make || "",
          model: niri.model || "",
          serial: niri.serial || "",
          workspace: ""
        })
      }
    }
    return normalized
  }

  function _ensureSelection() {
    var selected = outputByName(selectedOutputName)
    if (selected && selected.active) return

    var primaryName = ScreenManager.primaryScreen ? ScreenManager.primaryScreen.name : ""
    var primary = outputByName(primaryName)
    if (primary && primary.active) {
      selectedOutputName = primary.name
      return
    }
    for (var i = 0; i < outputs.length; i++) {
      if (outputs[i].active) {
        selectedOutputName = outputs[i].name
        return
      }
    }
    selectedOutputName = outputs.length > 0 ? outputs[0].name : ""
  }

  function _setPrimaryForOutput(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === name) {
        ScreenManager.setPrimary(screens[i])
        return
      }
    }
  }

  function selectOutput(name) {
    var output = outputByName(name)
    if (!output || !output.active) return
    selectedOutputName = name
    _setPrimaryForOutput(name)
    refreshBrightness()
  }

  function _isInternalOutput(output) {
    return output && /^(eDP|LVDS|DSI)-/.test(output.name)
  }

  function _requestOutputPower(name, active, automatic) {
    if (_outputPowerPending) return false
    _outputPowerPending = true
    _pendingOutputName = name
    _pendingOutputAutomatic = automatic
    Compositor.setOutputActive(name, active)
    return true
  }

  function setOutputActive(name, active) {
    var output = outputByName(name)
    if (!output || output.active === active || _outputPowerPending) return
    // Manual controls must never turn off the final active output.
    if (!active && activeCount <= 1) return
    _requestOutputPower(name, active, false)
  }

  function _setLidState(closed) {
    var changed = !lidStateKnown || lidClosed !== closed
    lidClosed = closed
    lidStateKnown = true
    if (changed) {
      _automaticRetryAttempted = false
      Compositor.fetchOutputs()
    }
  }

  function _parseLidLine(line, propertiesChangedOnly) {
    if (propertiesChangedOnly
        && (line.indexOf("PropertiesChanged") < 0 || line.indexOf("LidClosed") < 0)) return
    var match = line.match(/<(true|false)>/)
    if (match) _setLidState(match[1] === "true")
  }

  function _reconcileClamshell() {
    // Never apply policy against an assumed lid state or while compositor's
    // single output-power process is occupied.
    if (!lidStateKnown || _outputPowerPending) return

    var internals = []
    var activeExternalCount = 0
    for (var i = 0; i < outputs.length; i++) {
      if (_isInternalOutput(outputs[i])) internals.push(outputs[i])
      else if (outputs[i].active) activeExternalCount++
    }
    if (internals.length === 0) {
      _clamshellOutputName = ""
      return
    }

    var owned = outputByName(_clamshellOutputName)
    if (owned && !_isInternalOutput(owned)) owned = null
    if (!owned) _clamshellOutputName = ""

    if (lidClosed && activeExternalCount > 0) {
      var activeInternal = null
      for (var j = 0; j < internals.length; j++) {
        if (internals[j].active) {
          activeInternal = internals[j]
          break
        }
      }
      if (activeInternal) {
        _clamshellOutputName = activeInternal.name
        _requestOutputPower(activeInternal.name, false, true)
      } else if (!_clamshellOutputName) {
        // Adopt an already-disabled panel so opening the lid restores it.
        _clamshellOutputName = internals[0].name
      }
      return
    }

    if (owned && !owned.active) {
      // Opening the lid, or losing the last external while closed, restores
      // the panel owned/adopted by clamshell policy and avoids zero outputs.
      _requestOutputPower(owned.name, true, true)
      return
    }
    if (owned && owned.active) _clamshellOutputName = ""
  }

  function setScale(scale) {
    if (!selectedOutput || !selectedOutput.active) return
    if (scalePresets.indexOf(Number(scale)) < 0) return
    Compositor.applyScale(selectedOutput.name, Number(scale))
  }

  function getBrightnessIcon(percent) {
    if (percent < 25) return "󰃞"
    if (percent < 50) return "󰃟"
    if (percent < 75) return "󰃠"
    return "󰃡"
  }

  function refreshBrightness() {
    _brightnessGeneration++
    if (!selectedOutput || !selectedOutput.active) {
      brightnessAvailable = false
      return
    }
    if (brightnessRead.running) {
      _brightnessReadPending = true
      return
    }
    brightnessRead.connector = selectedOutput.name
    brightnessRead.generation = _brightnessGeneration
    brightnessRead.command = [brightnessCommand, "get", selectedOutput.name]
    brightnessRead.running = true
  }

  function setBrightness(percent) {
    if (!brightnessAvailable || !selectedOutput || !selectedOutput.active) return
    var target = Math.max(1, Math.min(100, Math.round(Number(percent))))
    _brightnessGeneration++
    selectedBrightness = target
    if (brightnessWrite.running) {
      _brightnessWritePending = true
      _pendingBrightnessConnector = selectedOutput.name
      _pendingBrightnessValue = target
      return
    }
    _startBrightnessWrite(selectedOutput.name, target)
  }

  function _startBrightnessWrite(connector, percent) {
    brightnessWrite.connector = connector
    brightnessWrite.value = percent
    brightnessWrite.command = [brightnessCommand, "set", connector, String(percent)]
    brightnessWrite.running = true
  }

  function adjustBrightness(direction) {
    if (!brightnessAvailable) return
    var step = selectedBrightness <= 5 ? 1 : 5
    setBrightness(selectedBrightness + (direction > 0 ? step : -step))
  }

  function setTextSize(value) {
    var number = Number(value)
    if (!isFinite(number) || Math.floor(number) !== number || number < 9 || number > 20)
      return "error: text size must be an integer between 9 and 20"
    if (config.textSize !== number) {
      config.textSize = number
      _applyTextSize()
    }
    return "Text size set to " + number + " px"
  }

  function _applyTextSize() {
    var clamped = Math.max(9, Math.min(20, Math.round(config.textSize)))
    if (config.textSize !== clamped) {
      config.textSize = clamped
      return
    }
    if (textSizeProcess.running || _textProcessValue === clamped) return
    _textProcessValue = clamped
    textSizeProcess.command = [textSizeCommand, String(clamped)]
    textSizeProcess.running = true
  }

  Component.onCompleted: {
    Compositor.fetchOutputs()
    lidInitial.running = true
    lidMonitor.running = true
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      displayManager._ensureSelection()
      Compositor.fetchOutputs()
    }
  }

  Connections {
    target: Compositor
    function onOutputsFetched(json) {
      displayManager.outputs = displayManager.normalizeOutputs(json)
      displayManager._ensureSelection()
      displayManager.refreshBrightness()
      displayManager._reconcileClamshell()
    }
    function onOutputPowerApplied(name, success) {
      if (!displayManager._outputPowerPending || name !== displayManager._pendingOutputName)
        return
      var automatic = displayManager._pendingOutputAutomatic
      displayManager._outputPowerPending = false
      displayManager._pendingOutputName = ""
      displayManager._pendingOutputAutomatic = false
      if (success) {
        displayManager._automaticRetryAttempted = false
      } else if (automatic && !displayManager._automaticRetryAttempted) {
        displayManager._automaticRetryAttempted = true
        clamshellRetry.start()
      } else if (!automatic) {
        displayManager._reconcileClamshell()
      }
    }
  }

  Process {
    id: lidInitial
    command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
      "--object-path", "/org/freedesktop/login1", "--method",
      "org.freedesktop.DBus.Properties.Get", "org.freedesktop.login1.Manager", "LidClosed"]
    stdout: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0 && !displayManager.lidStateKnown)
        displayManager._parseLidLine(lidInitial.stdout.text, false)
    }
  }

  Process {
    id: lidMonitor
    command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
      "--object-path", "/org/freedesktop/login1"]
    stdout: SplitParser {
      onRead: line => displayManager._parseLidLine(line, true)
    }
    onExited: lidMonitorRestart.start()
  }

  Timer {
    id: lidMonitorRestart
    interval: 2000
    repeat: false
    onTriggered: {
      if (!lidMonitor.running) lidMonitor.running = true
    }
  }

  Timer {
    id: clamshellRetry
    interval: 750
    repeat: false
    onTriggered: Compositor.fetchOutputs()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      if (!brightnessWrite.running && !displayManager._brightnessWritePending)
        displayManager.refreshBrightness()
    }
  }

  Process {
    id: brightnessRead
    property string connector: ""
    property int generation: 0
    stdout: StdioCollector {}
    onExited: exitCode => {
      var value = parseInt(brightnessRead.stdout.text.trim())
      if (connector === displayManager.selectedOutputName
          && generation === displayManager._brightnessGeneration) {
        displayManager.brightnessAvailable = exitCode === 0 && isFinite(value)
        if (displayManager.brightnessAvailable)
          displayManager.selectedBrightness = Math.max(1, Math.min(100, value))
      }
      if (displayManager._brightnessReadPending) {
        displayManager._brightnessReadPending = false
        displayManager.refreshBrightness()
      }
    }
  }

  Process {
    id: brightnessWrite
    property string connector: ""
    property int value: 50
    onExited: {
      if (displayManager._brightnessWritePending) {
        var connector = displayManager._pendingBrightnessConnector
        var value = displayManager._pendingBrightnessValue
        displayManager._brightnessWritePending = false
        displayManager._startBrightnessWrite(connector, value)
      }
    }
  }

  Process {
    id: textSizeProcess
    onExited: {
      if (displayManager._textProcessValue !== displayManager.textSize) {
        displayManager._textProcessValue = -1
        displayManager._applyTextSize()
      }
    }
  }

  IpcHandler {
    target: "display"

    function setTextSize(px: string): string {
      if (!/^\d+$/.test(px)) return "error: text size must be an integer between 9 and 20"
      return displayManager.setTextSize(Number(px))
    }

    function currentTextSize(): int { return displayManager.textSize }
  }
}
