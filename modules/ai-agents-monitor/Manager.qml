pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

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
  property var instances: []

  // Registry directory for OpenCode (set once at startup)
  property string registryDir: ""

  // Sessions directory for Claude Code (set once at startup)
  property string _ccSessionsDir: ""

  // Tasks directory for Claude Code (set once at startup)
  property string _ccTasksDir: ""

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
  }

  // Guard flags to prevent re-entry and coordinate merge timing
  property bool _ocBusy: false
  property bool _ccBusy: false

  // Poll every 10 seconds — orchestrates all provider discovery passes
  Timer {
    interval: 10000
    running: manager.registryDir !== "" || manager._ccSessionsDir !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (manager._ocBusy || manager._ccBusy) return
      manager._ocBusy = true
      manager._ccBusy = true
      manager._ocDiscover()
      manager._ccDiscover()
    }
  }

  // Only merge when both providers have finished their current cycle
  function _tryMerge() {
    if (!_ocBusy && !_ccBusy) _mergeProviders()
  }

  // Merge completed provider instance arrays into the shared `instances` list
  // and recompute aggregated counts.
  function _mergeProviders() {
    var merged = []
    for (var i = 0; i < _ocInstances.length; i++)
      merged.push(_ocInstances[i])
    for (var i = 0; i < _ccInstances.length; i++)
      merged.push(_ccInstances[i])

    manager.instances = merged
    manager.totalCount = merged.length

    var busy = 0
    var idle = 0
    var errors = 0
    var questions = 0
    for (var j = 0; j < merged.length; j++) {
      if (merged[j].status === "busy") busy++
      else if (merged[j].status === "idle") idle++
      else if (merged[j].status === "error") errors++
      else if (merged[j].status === "input") questions++
    }
    manager.busyCount = busy
    manager.idleCount = idle
    manager.errorCount = errors
    manager.questionCount = questions
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
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => discoverProc.output += data + "\n"
    }
    onExited: {
      var lines = discoverProc.output.trim().split("\n")
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
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => statusProc.output += data + "\n"
    }
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      manager._ocPendingSessionId = ""
      if (idx < manager._ocPending.length) {
        if (exitCode === 0 && statusProc.output.trim() !== "") {
          try {
            // Response is { "sessionId": { "type": "idle"|"busy"|"retry", ... }, ... }
            var statusMap = JSON.parse(statusProc.output.trim())
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
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => questionProc.output += data + "\n"
    }
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      if (idx < manager._ocPending.length && exitCode === 0 && questionProc.output.trim() !== "") {
        try {
          var questions = JSON.parse(questionProc.output.trim())
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
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => permissionProc.output += data + "\n"
    }
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      if (idx < manager._ocPending.length && exitCode === 0 && permissionProc.output.trim() !== "") {
        try {
          var permissions = JSON.parse(permissionProc.output.trim())
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
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => sessionProc.output += data + "\n"
    }
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ocPendingIdx
      if (idx < manager._ocPending.length && exitCode === 0 && sessionProc.output.trim() !== "") {
        try {
          var session = JSON.parse(sessionProc.output.trim())
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

  // Kick off Claude Code discovery
  function _ccDiscover() {
    ccDiscoverProc.command = ["bash", "-c",
      "shopt -s nullglob; " +
      "for f in \"" + manager._ccSessionsDir + "\"/*.json; do " +
      "  pid=$(basename \"$f\" .json); " +
      "  kill -0 \"$pid\" 2>/dev/null && echo \"$pid:$(cat \"$f\")\"; " +
      "done"
    ]
    ccDiscoverProc.running = true
  }

  // Read Claude session files and validate PIDs
  Process {
    id: ccDiscoverProc
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => ccDiscoverProc.output += data + "\n"
    }
    onExited: {
      var lines = ccDiscoverProc.output.trim().split("\n")
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
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => ccStatusProc.output += data + "\n"
    }
    onExited: function(exitCode, exitStatus) {
      var idx = manager._ccPendingIdx
      if (idx < manager._ccPending.length) {
        var raw = ccStatusProc.output.trim()
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
}
