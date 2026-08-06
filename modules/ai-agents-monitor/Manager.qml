pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: manager

  // Aggregated counts
  property int totalCount: 0
  property int busyCount: 0
  property int idleCount: 0
  property int errorCount: 0
  property int questionCount: 0

  // Per-instance details — normalized across all providers:
  //   { provider, pid, cwd, project, status, sessionTitle, <provider-specific> }
  // OpenCode extras: port
  // Remote extras: source, remote (imported from another dotshell over SSH)
  property var instances: []

  // Registry directory for OpenCode (set once at startup)
  property string registryDir: ""

  // Sessions directory for Claude Code (set once at startup)
  property string _ccSessionsDir: ""

  // Tasks directory for Claude Code (set once at startup)
  property string _ccTasksDir: ""

  // Sessions directory for Pi (set once at startup)
  property string _piSessionsDir: ""

  Component.onCompleted: {
    var xdgRuntime = Quickshell.env("XDG_RUNTIME_DIR")
    if (!xdgRuntime) xdgRuntime = "/run/user/1000"
    registryDir = xdgRuntime + "/opencode-ports"

    var xdgConfig = Quickshell.env("XDG_CONFIG_HOME")
    if (!xdgConfig) {
      var home = Quickshell.env("HOME")
      xdgConfig = (home ? home : "/root") + "/.config"
    }
    _ccSessionsDir = xdgConfig + "/claude/sessions"
    _ccTasksDir = xdgConfig + "/claude/tasks"
    _piSessionsDir = xdgConfig + "/pi/sessions"
  }

  // Guard flags to prevent re-entry and coordinate merge timing
  property bool _ocBusy: false
  property bool _ccBusy: false
  property bool _piBusy: false

  // Poll every 10 seconds — orchestrates all provider discovery passes
  Timer {
    interval: 10000
    running: manager.registryDir !== "" || manager._ccSessionsDir !== "" || manager._piSessionsDir !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (manager._ocBusy || manager._ccBusy || manager._piBusy) return
      manager._ocBusy = true
      manager._ccBusy = true
      manager._piBusy = true
      manager._ocDiscover()
      manager._ccDiscover()
      manager._piDiscover()
    }
  }

  // Only merge when all providers have finished their current cycle
  function _tryMerge() {
    if (!_ocBusy && !_ccBusy && !_piBusy) _mergeProviders()
  }

  // Locally discovered instances only — this is what gets exported to
  // subscribers, so imported remote instances can never be re-exported.
  property var _localInstances: []
  property bool _localReady: false
  property double _localGeneratedAtMs: 0

  // Merge completed provider instance arrays into the local snapshot,
  // broadcast it to IPC subscribers, and republish the display list.
  function _mergeProviders() {
    var merged = []
    for (var i = 0; i < _ocInstances.length; i++)
      merged.push(_ocInstances[i])
    for (var j = 0; j < _ccInstances.length; j++)
      merged.push(_ccInstances[j])
    for (var k = 0; k < _piInstances.length; k++)
      merged.push(_piInstances[k])

    _localInstances = merged
    _localGeneratedAtMs = Date.now()
    _localReady = true
    agentsIpc.snapshot(_snapshotJson())
    _publish()
  }

  // Combine local and imported remote instances into the shared `instances`
  // list and recompute aggregated counts.
  function _publish() {
    var merged = []
    for (var i = 0; i < _localInstances.length; i++)
      merged.push(_localInstances[i])
    for (var j = 0; j < _remoteInstances.length; j++)
      merged.push(_remoteInstances[j])

    manager.instances = merged
    manager.totalCount = merged.length

    var busy = 0
    var idle = 0
    var errors = 0
    var questions = 0
    for (var k = 0; k < merged.length; k++) {
      if (merged[k].status === "busy") busy++
      else if (merged[k].status === "idle") idle++
      else if (merged[k].status === "error") errors++
      else if (merged[k].status === "input") questions++
    }
    manager.busyCount = busy
    manager.idleCount = idle
    manager.errorCount = errors
    manager.questionCount = questions
  }

  // Compact v1 snapshot of local instances only — display fields, no
  // pid/cwd/port/sessionId.
  function _snapshotJson() {
    var list = []
    for (var i = 0; i < _localInstances.length; i++) {
      var inst = _localInstances[i]
      list.push({
        provider: inst.provider,
        project: inst.project,
        status: inst.status,
        sessionTitle: inst.sessionTitle
      })
    }
    return JSON.stringify({
      version: 1,
      ready: _localReady,
      generatedAtMs: _localGeneratedAtMs,
      instances: list
    })
  }

  // Read/subscribe surface for other dotshell instances: `call agents
  // current` returns the latest snapshot, `listen agents snapshot` receives
  // a push after every completed local provider poll.
  IpcHandler {
    id: agentsIpc
    target: "agents"

    signal snapshot(payload: string)

    function current(): string {
      return manager._snapshotJson()
    }
  }

  // -------------------------------------------------------------------------
  // OpenCode provider discovery
  // -------------------------------------------------------------------------

  // Completed OpenCode instances for the current poll cycle
  property var _ocInstances: []

  // State for the async query chain
  property var _ocPending: []
  property int _ocPendingIdx: 0
  property string _ocPendingSessionId: ""

  // Kick off OpenCode discovery (Step 1)
  function _ocDiscover() {
    discoverProc.command = ["bash", "-c",
      "shopt -s nullglob; " +
      "for f in \"" + manager.registryDir + "\"/*.json; do " +
      "  pid=$(basename \"$f\" .json); " +
      "  if kill -0 \"$pid\" 2>/dev/null; then " +
      "    echo \"$pid:$(cat \"$f\")\"; " +
      "  else " +
      "    rm -f \"$f\"; " +
      "  fi; " +
      "done"
    ]
    discoverProc.running = true
  }

  // Step 1: read OpenCode registry files and validate PIDs
  Process {
    id: discoverProc
    stdout: StdioCollector {}
    onExited: {
      var lines = discoverProc.stdout.text.trim().split("\n")
      var discovered = []

      for (var i = 0; i < lines.length; i++) {
        if (lines[i] === "") continue
        var colonIdx = lines[i].indexOf(":")
        if (colonIdx < 0) continue

        var pid = lines[i].substring(0, colonIdx)
        var jsonStr = lines[i].substring(colonIdx + 1)

        try {
          var info = JSON.parse(jsonStr)
          var parts = info.cwd.split("/")
          discovered.push({
            provider: "opencode",
            pid: pid,
            port: info.port,
            cwd: info.cwd,
            project: parts[parts.length - 1],
            status: "unknown",
            sessionTitle: ""
          })
        } catch(e) {
          // Skip malformed registry files
        }
      }

      if (discovered.length === 0) {
        manager._ocInstances = []
        manager._ocBusy = false
        manager._tryMerge()
        return
      }

      // Carry over session titles from previous cycle (matched by PID)
      var prev = {}
      for (var j = 0; j < manager._ocInstances.length; j++)
        prev[manager._ocInstances[j].pid] = manager._ocInstances[j].sessionTitle || ""
      for (var k = 0; k < discovered.length; k++)
        if (prev[discovered[k].pid]) discovered[k].sessionTitle = prev[discovered[k].pid]

      // Store discovered instances, then query their status
      manager._ocPending = discovered
      manager._ocPendingIdx = 0
      manager._ocQueryNext()
    }
  }

  // Drive the per-instance OpenCode query chain
  function _ocQueryNext() {
    if (_ocPendingIdx >= _ocPending.length) {
      // All OpenCode queries done — publish results
      manager._ocInstances = _ocPending
      manager._ocBusy = false
      manager._tryMerge()
      return
    }

    var instance = _ocPending[_ocPendingIdx]
    statusProc.command = ["curl", "-sf", "--connect-timeout", "1", "--max-time", "2",
      "http://127.0.0.1:" + instance.port + "/session/status"]
    statusProc.running = true
  }

  // Advance to session title fetch or next instance
  function _ocFetchSessionOrAdvance() {
    if (manager._ocPendingSessionId !== "") {
      var instance = manager._ocPending[manager._ocPendingIdx]
      sessionProc.command = ["curl", "-sf", "--connect-timeout", "1", "--max-time", "2",
        "http://127.0.0.1:" + instance.port + "/session/" + manager._ocPendingSessionId]
      sessionProc.running = true
    } else {
      manager._ocPendingIdx++
      manager._ocQueryNext()
    }
  }

  // Step 2: query each OpenCode instance's session status via HTTP
  Process {
    id: statusProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      manager._ocPendingSessionId = ""
      if (idx < manager._ocPending.length) {
        if (exitCode === 0 && statusProc.stdout.text.trim() !== "") {
          try {
            // Response is { "sessionId": { "type": "idle"|"busy"|"retry", ... }, ... }
            var statusMap = JSON.parse(statusProc.stdout.text.trim())
            var hasBusy = false
            var hasRetry = false
            var keys = Object.keys(statusMap)
            for (var i = 0; i < keys.length; i++) {
              var s = statusMap[keys[i]]
              if (s && s.type === "busy") hasBusy = true
              else if (s && s.type === "retry") hasRetry = true
            }
            if (hasRetry) manager._ocPending[idx].status = "error"
            else if (hasBusy) manager._ocPending[idx].status = "busy"
            else manager._ocPending[idx].status = "idle"

            // Pick the first session ID for title lookup
            if (keys.length > 0) manager._ocPendingSessionId = keys[0]
          } catch(e) {
            manager._ocPending[idx].status = "error"
          }
        } else {
          // curl failed — server unreachable
          manager._ocPending[idx].status = "error"
        }
      }

      // If the instance is busy, check for pending questions
      if (manager._ocPending[idx].status === "busy") {
        var instance = manager._ocPending[idx]
        questionProc.command = ["curl", "-sf", "--connect-timeout", "1", "--max-time", "2",
          "http://127.0.0.1:" + instance.port + "/question"]
        questionProc.running = true
      } else {
        manager._ocFetchSessionOrAdvance()
      }
    }
  }

  // Step 3: check for pending questions (only when busy)
  Process {
    id: questionProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      if (idx < manager._ocPending.length && exitCode === 0 && questionProc.stdout.text.trim() !== "") {
        try {
          var questions = JSON.parse(questionProc.stdout.text.trim())
          if (Array.isArray(questions) && questions.length > 0)
            manager._ocPending[idx].status = "input"
        } catch(e) {
          // Parse failed — keep busy status
        }
      }

      // If still busy (no questions found), check for pending permissions
      if (manager._ocPending[idx].status === "busy") {
        var instance = manager._ocPending[idx]
        permissionProc.command = ["curl", "-sf", "--connect-timeout", "1", "--max-time", "2",
          "http://127.0.0.1:" + instance.port + "/permission"]
        permissionProc.running = true
      } else {
        manager._ocFetchSessionOrAdvance()
      }
    }
  }

  // Step 3b: check for pending permissions (only when busy + no questions)
  Process {
    id: permissionProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      if (idx < manager._ocPending.length && exitCode === 0 && permissionProc.stdout.text.trim() !== "") {
        try {
          var permissions = JSON.parse(permissionProc.stdout.text.trim())
          if (Array.isArray(permissions) && permissions.length > 0)
            manager._ocPending[idx].status = "input"
        } catch(e) {
          // Parse failed — keep busy status
        }
      }

      manager._ocFetchSessionOrAdvance()
    }
  }

  // Step 4: fetch session title for the active OpenCode session
  Process {
    id: sessionProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      if (idx < manager._ocPending.length && exitCode === 0 && sessionProc.stdout.text.trim() !== "") {
        try {
          var session = JSON.parse(sessionProc.stdout.text.trim())
          if (session.title) manager._ocPending[idx].sessionTitle = session.title
        } catch(e) {
          // Title unavailable — leave empty
        }
      }

      manager._ocPendingIdx++
      manager._ocQueryNext()
    }
  }

  // -------------------------------------------------------------------------
  // Claude Code provider discovery
  // -------------------------------------------------------------------------

  // Completed Claude Code instances for the current poll cycle
  property var _ccInstances: []

  // State for the async status query chain
  property var _ccPending: []
  property int _ccPendingIdx: 0

  // Kick off Claude Code discovery. The helper filters Claude processes that
  // are descendants of Pi, which means pi-claude-bridge is driving Claude and
  // Pi should be the single counted agent instance.
  function _ccDiscover() {
    ccDiscoverProc.command = ["bash",
      Quickshell.shellDir + "/modules/ai-agents-monitor/bin/claude-discover"]
    ccDiscoverProc.running = true
  }

  // Read Claude session files and validate PIDs
  Process {
    id: ccDiscoverProc
    stdout: StdioCollector {}
    onExited: {
      var lines = ccDiscoverProc.stdout.text.trim().split("\n")
      var discovered = []

      for (var i = 0; i < lines.length; i++) {
        if (lines[i] === "") continue
        var colonIdx = lines[i].indexOf(":")
        if (colonIdx < 0) continue

        var pid = lines[i].substring(0, colonIdx)
        var jsonStr = lines[i].substring(colonIdx + 1)

        try {
          var info = JSON.parse(jsonStr)
          var parts = info.cwd.split("/")
          discovered.push({
            provider: "claude-code",
            pid: pid,
            sessionId: info.sessionId,
            cwd: info.cwd,
            project: parts[parts.length - 1],
            status: "idle",
            sessionTitle: ""
          })
        } catch(e) {
          // Skip malformed session files
        }
      }

      if (discovered.length === 0) {
        manager._ccInstances = []
        manager._ccBusy = false
        manager._tryMerge()
        return
      }

      manager._ccPending = discovered
      manager._ccPendingIdx = 0
      manager._ccQueryNext()
    }
  }

  // Drive the per-instance Claude Code task status query chain
  function _ccQueryNext() {
    if (_ccPendingIdx >= _ccPending.length) {
      manager._ccInstances = _ccPending
      manager._ccBusy = false
      manager._tryMerge()
      return
    }

    var instance = _ccPending[_ccPendingIdx]
    var sessionId = instance.sessionId || ""

    // Skip status query if sessionId is missing to avoid reading root tasks dir
    if (!sessionId) {
      manager._ccPendingIdx++
      manager._ccQueryNext()
      return
    }

    var tasksDir = manager._ccTasksDir + "/" + sessionId
    ccStatusProc.command = ["bash", "-c",
      "shopt -s nullglob; " +
      "for f in \"" + tasksDir + "\"/*.json; do " +
      "  cat \"$f\"; " +
      "  echo '__SEP__'; " +
      "done"
    ]
    ccStatusProc.running = true
  }

  // Read task JSON files for the current Claude session
  Process {
    id: ccStatusProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ccPendingIdx
      if (idx < manager._ccPending.length) {
        var raw = ccStatusProc.stdout.text.trim()
        var hasInProgress = false
        var hasError = false

        if (raw !== "") {
          var chunks = raw.split("__SEP__")
          for (var i = 0; i < chunks.length; i++) {
            var chunk = chunks[i].trim()
            if (chunk === "") continue
            try {
              var task = JSON.parse(chunk)
              if (task.status === "in_progress") hasInProgress = true
              if (task.title && !manager._ccPending[idx].sessionTitle)
                manager._ccPending[idx].sessionTitle = task.title
            } catch(e) {
              hasError = true
            }
          }
        }

        if (hasError && !hasInProgress)
          manager._ccPending[idx].status = "error"
        else if (hasInProgress)
          manager._ccPending[idx].status = "busy"
        // else: leave as "idle" (no tasks or all pending)
      }

      manager._ccPendingIdx++
      manager._ccQueryNext()
    }
  }

  // -------------------------------------------------------------------------
  // Pi provider discovery
  // -------------------------------------------------------------------------

  // Completed Pi instances for the current poll cycle
  property var _piInstances: []

  // Kick off Pi discovery — delegates to bin/pi-discover which correlates
  // live `pi` processes against on-disk JSONL session files by cwd.
  function _piDiscover() {
    if (manager._piSessionsDir === "") {
      manager._piInstances = []
      manager._piBusy = false
      manager._tryMerge()
      return
    }
    piDiscoverProc.command = ["bash",
      Quickshell.shellDir + "/modules/ai-agents-monitor/bin/pi-discover"]
    piDiscoverProc.running = true
  }

  Process {
    id: piDiscoverProc
    stdout: StdioCollector {}
    onExited: {
      var lines = piDiscoverProc.stdout.text.trim().split("\n")
      var discovered = []

      for (var i = 0; i < lines.length; i++) {
        if (lines[i] === "") continue
        var fields = lines[i].split("\t")
        if (fields.length < 4) continue

        var pid = fields[0]
        var cwd = fields[1]
        var sessionId = fields[2]
        var status = fields[3]
        var sessionTitle = fields.length >= 5 ? fields[4] : ""

        var parts = cwd.split("/")
        discovered.push({
          provider: "pi",
          pid: pid,
          sessionId: sessionId,
          cwd: cwd,
          project: parts[parts.length - 1],
          status: status,
          sessionTitle: sessionTitle
        })
      }

      manager._piInstances = discovered
      manager._piBusy = false
      manager._tryMerge()
    }
  }

  // -------------------------------------------------------------------------
  // Remote subscription (client mode)
  // -------------------------------------------------------------------------

  // SSH host alias of another dotshell machine to import agents from.
  // Blank keeps this instance in publisher/local-only mode.
  property alias remoteHost: remoteConfigAdapter.remoteHost
  readonly property bool remoteConfigured: remoteHost.trim() !== ""

  // Transport state: "" (off), "connecting", "connected", or "stale"
  property string remoteState: ""

  // Imported instances, already validated and annotated with source/remote
  // by bin/remote-stream
  property var _remoteInstances: []
  property double _remoteGeneratedAtMs: -1
  property double _remoteFreshAtMs: 0

  ModuleConfig {
    moduleId: "ai-agents-monitor"
    scope: "general"
    adapter: JsonAdapter {
      id: remoteConfigAdapter
      property string remoteHost: ""
    }
  }

  onRemoteHostChanged: _restartRemote()

  function _restartRemote() {
    _remoteInstances = []
    _remoteGeneratedAtMs = -1
    _remoteFreshAtMs = Date.now()
    if (remoteProc.running) {
      remoteProc.running = false
    } else if (remoteConfigured) {
      remoteState = "connecting"
      _startRemoteStream()
    }
    if (!remoteConfigured) remoteState = ""
    _publish()
  }

  function _startRemoteStream() {
    if (!remoteConfigured || remoteProc.running) return
    if (_remoteFreshAtMs === 0) _remoteFreshAtMs = Date.now()
    if (remoteState === "") remoteState = "connecting"
    remoteProc.command = ["bash",
      Quickshell.shellDir + "/modules/ai-agents-monitor/bin/remote-stream",
      remoteHost.trim()]
    remoteProc.running = true
  }

  // Apply one validated snapshot line from remote-stream. An advancing
  // generation refreshes freshness; transport failures never touch local
  // provider polling or the agent error count.
  function _remoteIngest(line) {
    var trimmed = line.trim()
    if (trimmed === "") return

    var payload
    try {
      payload = JSON.parse(trimmed)
    } catch(e) {
      return
    }
    if (!payload || payload.version !== 1 || !Array.isArray(payload.instances)) return
    if (payload.source !== remoteHost.trim()) return
    if (typeof payload.generatedAtMs !== "number" || !isFinite(payload.generatedAtMs)) return

    var generation = payload.generatedAtMs
    if (generation <= _remoteGeneratedAtMs) return

    _remoteGeneratedAtMs = generation
    _remoteFreshAtMs = Date.now()
    _remoteInstances = payload.instances
    remoteState = "connected"
    _publish()
  }

  Process {
    id: remoteProc
    stdout: SplitParser {
      onRead: line => manager._remoteIngest(line)
    }
    onExited: function(exitCode) {
      if (manager.remoteConfigured) {
        // Keep imported rows for now; the stale timer clears them if the
        // stream stays down.
        if (manager.remoteState !== "stale") manager.remoteState = "connecting"
        console.warn("[AiAgentsMonitor] Remote stream exited with code", exitCode)
      } else {
        manager.remoteState = ""
      }
    }
  }

  // Ensure a configured stream starts after persisted config loads, and
  // restart it within five seconds if the process exits.
  Timer {
    interval: 5000
    running: manager.remoteConfigured
    repeat: true
    triggeredOnStart: true
    onTriggered: manager._startRemoteStream()
  }

  // Drop imported rows once the stream has gone 60s without an advancing
  // generation, so counts never show a dead remote as active.
  Timer {
    interval: 10000
    running: manager.remoteConfigured
    repeat: true
    onTriggered: {
      if (manager.remoteState === "stale") return
      if (Date.now() - manager._remoteFreshAtMs > 60000) {
        manager.remoteState = "stale"
        manager._remoteInstances = []
        manager._publish()
      }
    }
  }
}
