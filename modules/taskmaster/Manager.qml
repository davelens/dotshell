pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: manager

  property int totalCount: 0
  // [{ project, sessionDescription, duration, start }]
  property var runningTasks: []

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      pollProc.command = ["bash", Quickshell.shellDir + "/modules/taskmaster/bin/list-sessions"]
      pollProc.running = true
    }
  }

  Process {
    id: pollProc
    property string output: ""

    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => pollProc.output += data + "\n"
    }

    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || pollProc.output.trim() === "") {
        manager.runningTasks = []
        manager.totalCount = 0
        return
      }

      try {
        var parsed = JSON.parse(pollProc.output.trim())
        if (!Array.isArray(parsed)) throw new Error("Invalid task data")

        var normalized = []
        for (var i = 0; i < parsed.length; i++) {
          var item = parsed[i]
          if (!item) continue
          normalized.push({
            project: item.project ? String(item.project) : "Unknown",
            sessionDescription: item.sessionDescription ? String(item.sessionDescription) : "",
            duration: item.duration ? String(item.duration) : "00:00",
            start: item.start ? parseInt(item.start) : 0
          })
        }

        manager.runningTasks = normalized
        manager.totalCount = normalized.length
      } catch (e) {
        manager.runningTasks = []
        manager.totalCount = 0
      }
    }
  }
}
