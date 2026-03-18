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

  // Per-instance details: [{project, cwd, port, status}]
  property var instances: []

  // Registry directory (set once at startup)
  property string registryDir: ""

  Component.onCompleted: {
    var xdgRuntime = Quickshell.env("XDG_RUNTIME_DIR")
    if (!xdgRuntime) xdgRuntime = "/run/user/1000"
    registryDir = xdgRuntime + "/opencode-ports"
  }

  // Poll every 3 seconds
  Timer {
    interval: 3000
    running: manager.registryDir !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      // Step 1: discover instances from registry files
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
  }

  // Step 1: read registry files and validate PIDs
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
            pid: pid,
            port: info.port,
            cwd: info.cwd,
            project: parts[parts.length - 1],
            status: "unknown"
          })
        } catch(e) {
          // Skip malformed registry files
        }
      }

      if (discovered.length === 0) {
        manager.instances = []
        manager.totalCount = 0
        manager.busyCount = 0
        manager.idleCount = 0
        manager.errorCount = 0
        return
      }

      // Store discovered instances, then query their status
      manager._pending = discovered
      manager._pendingIdx = 0
      manager._queryNext()
    }
  }

  // Pending status queries
  property var _pending: []
  property int _pendingIdx: 0

  function _queryNext() {
    if (_pendingIdx >= _pending.length) {
      // All queries done, update public properties
      manager.instances = _pending
      manager.totalCount = _pending.length
      var busy = 0
      var idle = 0
      var errors = 0
      for (var i = 0; i < _pending.length; i++) {
        if (_pending[i].status === "busy") busy++
        else if (_pending[i].status === "idle") idle++
        else if (_pending[i].status === "error") errors++
      }
      manager.busyCount = busy
      manager.idleCount = idle
      manager.errorCount = errors
      return
    }

    var instance = _pending[_pendingIdx]
    statusProc.command = ["curl", "-sf", "--connect-timeout", "1", "--max-time", "2",
      "http://127.0.0.1:" + instance.port + "/session/status"]
    statusProc.running = true
  }

  // Step 2: query each instance's session status via HTTP
  Process {
    id: statusProc
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => statusProc.output += data + "\n"
    }
    onExited: function(exitCode, exitStatus) {
      var idx = manager._pendingIdx
      if (idx < manager._pending.length) {
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
            if (hasRetry) manager._pending[idx].status = "error"
            else if (hasBusy) manager._pending[idx].status = "busy"
            else manager._pending[idx].status = "idle"
          } catch(e) {
            manager._pending[idx].status = "error"
          }
        } else {
          // curl failed — server unreachable
          manager._pending[idx].status = "error"
        }
      }

      manager._pendingIdx++
      manager._queryNext()
    }
  }
}
