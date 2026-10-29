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
  //   { provider, pid, cwd, project, status, sessionTitle }
  // Remote extras: source, remote (imported from another dotshell over SSH)
  property var instances: []

  // -------------------------------------------------------------------------
  // Local agents, pushed over a Unix socket
  // -------------------------------------------------------------------------

  // Agents write one JSON line per status change:
  //   { provider, pid, status, cwd?, title?, oneshot? }
  // Status "gone" removes the agent. Pi and OpenCode keep their connection
  // open, so closing it removes their agent too. Claude Code hooks send
  // `oneshot` lines and are pruned by the liveness timer instead.
  readonly property string socketPath:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/dotshell-agents.sock"

  readonly property var _providers: ({ "opencode": true, "claude-code": true, "pi": true })
  readonly property var _statuses: ({ "busy": true, "idle": true, "error": true, "input": true })

  // Local agents keyed by "<provider>:<pid>", and the persistent connection
  // that owns each of them
  property var _agents: ({})
  property var _owners: ({})

  SocketServer {
    active: true
    path: manager.socketPath
    handler: Socket {
      id: conn
      onConnectedChanged: if (!connected) manager._disconnect(conn)
      parser: SplitParser {
        onRead: line => manager._ingest(line, conn)
      }
    }
  }

  function _ingest(line, conn) {
    var msg
    try {
      msg = JSON.parse(line)
    } catch(e) {
      return
    }
    if (_apply(msg, conn)) _publishLocal()
  }

  // Validate one agent message and fold it into _agents. Returns whether
  // anything changed.
  function _apply(msg, conn) {
    if (!msg || !_providers[msg.provider]) return false
    if (typeof msg.pid !== "number" || msg.pid <= 0 || msg.pid % 1 !== 0) return false

    var key = msg.provider + ":" + msg.pid
    if (msg.status === "gone") {
      if (!(key in _agents)) return false
      delete _agents[key]
      delete _owners[key]
      return true
    }
    if (!_statuses[msg.status]) return false

    var prev = _agents[key] || {}
    var cwd = typeof msg.cwd === "string" && msg.cwd !== "" ? msg.cwd : (prev.cwd || "")
    var parts = cwd.split("/")
    _agents[key] = {
      provider: msg.provider,
      pid: String(msg.pid),
      cwd: cwd,
      project: parts[parts.length - 1],
      status: msg.status,
      sessionTitle: typeof msg.title === "string" ? msg.title : (prev.sessionTitle || "")
    }
    if (!msg.oneshot && conn) _owners[key] = conn
    return true
  }

  // A replaced Pi session reconnects before its old socket closes, so only
  // drop agents this connection still owns.
  function _disconnect(conn) {
    var changed = false
    for (var key in _owners) {
      if (_owners[key] !== conn) continue
      delete _owners[key]
      delete _agents[key]
      changed = true
    }
    if (changed) _publishLocal()
  }

  // Seeds Claude sessions started before the shell, prunes ones that exited
  // without a SessionEnd hook, and doubles as the snapshot heartbeat for
  // remote subscribers.
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: claudeDiscoverProc.running = true
  }

  // bin/claude-discover skips Claude processes driven by Pi, which is the
  // single counted agent in that case.
  Process {
    id: claudeDiscoverProc
    command: ["bash", Quickshell.shellDir + "/modules/ai-agents-monitor/bin/claude-discover"]
    stdout: StdioCollector {}
    onExited: {
      var live = {}
      var lines = claudeDiscoverProc.stdout.text.trim().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var colonIdx = lines[i].indexOf(":")
        if (colonIdx < 0) continue
        try {
          live[lines[i].substring(0, colonIdx)] = JSON.parse(lines[i].substring(colonIdx + 1)).cwd
        } catch(e) {
          // Skip malformed session files
        }
      }

      for (var key in manager._agents) {
        if (key.indexOf("claude-code:") === 0 && !(key.substring(12) in live))
          delete manager._agents[key]
      }
      for (var pid in live) {
        if (!(("claude-code:" + pid) in manager._agents))
          manager._apply({ provider: "claude-code", pid: Number(pid), status: "idle", cwd: live[pid], oneshot: true }, null)
      }

      manager._localReady = true
      manager._publishLocal()
    }
  }

  // Locally discovered instances only — this is what gets exported to
  // subscribers, so imported remote instances can never be re-exported.
  property var _localInstances: []
  property bool _localReady: false
  property double _localGeneratedAtMs: 0

  // Rebuild the local snapshot, broadcast it to IPC subscribers, and
  // republish the display list.
  function _publishLocal() {
    var list = []
    for (var key in _agents)
      list.push(_agents[key])

    _localInstances = list
    // Remote subscribers drop non-advancing generations, so never repeat one.
    _localGeneratedAtMs = Math.max(Date.now(), _localGeneratedAtMs + 1)
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
  // pid/cwd.
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
  // a push after every local change and at least once a minute.
  IpcHandler {
    id: agentsIpc
    target: "agents"

    signal snapshot(payload: string)

    function current(): string {
      return manager._snapshotJson()
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

  // Drop imported rows once the stream has gone 150s without an advancing
  // generation (the publisher heartbeats every 60s), so counts never show a
  // dead remote as active.
  Timer {
    interval: 10000
    running: manager.remoteConfigured
    repeat: true
    onTriggered: {
      if (manager.remoteState === "stale") return
      if (Date.now() - manager._remoteFreshAtMs > 150000) {
        manager.remoteState = "stale"
        manager._remoteInstances = []
        manager._publish()
      }
    }
  }
}
