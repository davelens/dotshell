pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: manager

  readonly property string backendPath: Quickshell.shellDir + "/modules/updates/backends/run"

  property alias includeFlatpak: settingsAdapter.includeFlatpak

  ModuleConfig {
    moduleId: "updates"
    adapter: JsonAdapter {
      id: settingsAdapter
      property bool includeFlatpak: false
    }
  }

  // Distribution backend description.
  property bool backendReady: false
  property bool backendSupported: false
  property string backendName: "Linux"
  property string repoLabel: "System"
  property string communityLabel: ""
  property bool hasCommunity: false
  property string systemUpdateDescription: "System upgrade"
  property string systemUpdateRunningDescription: "Running system upgrade"

  // Each update is { name, currentVersion, newVersion, source }.
  // Flatpak updates additionally expose appId.
  property var repoUpdates: []
  property var communityUpdates: []
  property var flatpakUpdates: []

  property int repoCount: 0
  property int communityCount: 0
  property int flatpakCount: 0
  readonly property int totalCount: repoCount + communityCount + flatpakCount

  readonly property var sourceModels: {
    var sources = [{ id: "repo", label: repoLabel, updates: repoUpdates }]
    if (hasCommunity) {
      sources.push({ id: "community", label: communityLabel, updates: communityUpdates })
    }
    sources.push({ id: "flatpak", label: "Flatpak", updates: flatpakUpdates })
    return sources
  }

  property bool checking: false
  property bool systemUpdating: false
  property var updatingPackages: ({})
  readonly property bool blocked: systemUpdating

  readonly property string iconError: "󰒑"
  readonly property string iconUpToDate: "󰸟"
  readonly property string iconHasUpdates: "󰄠"
  readonly property string iconDownload: "󰇚"

  function getIcon() {
    if (checking || totalCount > 0) return iconHasUpdates
    return iconUpToDate
  }

  function isUpdating(name) {
    return updatingPackages[name] === true
  }

  function sourceUpdates(source) {
    if (source === "repo") return repoUpdates
    if (source === "community") return communityUpdates
    return flatpakUpdates
  }

  function packageKey(pkg, source) {
    return source === "flatpak" ? pkg.appId : pkg.name
  }

  function checkUpdates() {
    if (checking || !backendReady) return
    checking = true
    if (backendSupported) checkNativeProc.running = true
    else checkFlatpakProc.running = true
  }

  function findPackage(name, source) {
    var list = sourceUpdates(source)
    for (var i = 0; i < list.length; i++) {
      if (packageKey(list[i], source) === name) return list[i]
    }
    return null
  }

  function setSourceUpdates(source, updates) {
    if (source === "repo") {
      repoUpdates = updates
      repoCount = updates.length
    } else if (source === "community") {
      communityUpdates = updates
      communityCount = updates.length
    } else {
      flatpakUpdates = updates
      flatpakCount = updates.length
    }
  }

  function removePackage(name, source) {
    var filtered = sourceUpdates(source).filter(function(pkg) {
      return packageKey(pkg, source) !== name
    })
    setSourceUpdates(source, filtered)
  }

  function markUpdating(source, updates) {
    var marked = Object.assign({}, updatingPackages)
    for (var i = 0; i < updates.length; i++) {
      marked[packageKey(updates[i], source)] = true
    }
    updatingPackages = marked
  }

  function updatePackage(name, source) {
    if (systemUpdating || isUpdating(name)) return

    var pkg = findPackage(name, source)
    var marked = Object.assign({}, updatingPackages)
    marked[name] = true
    updatingPackages = marked

    var command = source === "flatpak"
      ? ["flatpak", "update", "-y", name]
      : [backendPath, "update-package", source, name]
    singleUpdateHelper.start(command, name, source,
      pkg ? pkg.currentVersion : "", pkg ? pkg.newVersion : "")
  }

  function updateSource(source) {
    if (systemUpdating) return
    var updates = sourceUpdates(source)
    if (updates.length === 0) return

    sourceUpdateProc.source = source
    sourceUpdateProc.command = source === "flatpak"
      ? ["flatpak", "update", "-y"]
      : [backendPath, "update-source", source].concat(
          updates.map(function(pkg) { return pkg.name }))
    markUpdating(source, updates)
    sourceUpdateProc.running = true
  }

  function systemUpdate() {
    if (systemUpdating) return
    systemUpdating = true

    if (backendSupported) {
      systemUpdateProc.command = [backendPath, "system-update", includeFlatpak ? "1" : "0"]
    } else if (includeFlatpak) {
      systemUpdateProc.command = ["flatpak", "update", "-y"]
    } else {
      systemUpdating = false
      return
    }
    systemUpdateProc.running = true
  }

  function onSystemUpdateComplete(success, exitCode) {
    systemUpdating = false
    updatingPackages = {}
    if (success) {
      notifyProc.command = ["notify-send", "-a", "General", "System Updates", "System update completed successfully", "-i", "package-install"]
    } else {
      var body = "System update failed (exit " + exitCode + ")"
      var tail = tailLines(systemUpdateProc.stderr.text, 8)
      if (tail) body += "\n" + tail
      notifyProc.command = ["notify-send", "-a", "General", "-u", "critical", "System Updates", body, "-i", "dialog-error"]
    }
    notifyProc.running = true
    recheckTimer.restart()
  }

  function tailLines(buffer, count) {
    if (!buffer) return ""
    var lines = String(buffer).split("\n").filter(function(line) {
      return line.trim().length > 0
    })
    if (lines.length === 0) return ""
    return lines.slice(Math.max(0, lines.length - count)).join("\n")
  }

  QtObject {
    id: singleUpdateHelper
    property var queue: []
    property bool busy: false

    function start(command, packageName, source, fromVersion, toVersion) {
      queue.push({
        command: command,
        name: packageName,
        source: source,
        from: fromVersion || "",
        to: toVersion || ""
      })
      processNext()
    }

    function processNext() {
      if (busy || queue.length === 0) return
      busy = true
      var item = queue.shift()
      singleProc.pkgName = item.name
      singleProc.source = item.source
      singleProc.fromVersion = item.from
      singleProc.toVersion = item.to
      singleProc.command = item.command
      singleProc.running = true
    }

    function onFinished(packageName, source, fromVersion, toVersion, exitCode) {
      busy = false
      var marked = Object.assign({}, manager.updatingPackages)
      delete marked[packageName]
      manager.updatingPackages = marked

      if (exitCode === 0) {
        var body = "Updated " + packageName
        if (fromVersion && toVersion) body += "\n" + fromVersion + " → " + toVersion
        notifyProc.command = ["notify-send", "-a", "General", "System Updates", body, "-i", "package-install"]
        manager.removePackage(packageName, source)
      } else {
        var errorBody = "Failed to update " + packageName + " (exit " + exitCode + ")"
        var tail = manager.tailLines(singleProc.stderr.text, 6)
        if (tail) errorBody += "\n" + tail
        notifyProc.command = ["notify-send", "-a", "General", "-u", "critical", "System Updates", errorBody, "-i", "dialog-error"]
      }
      notifyProc.running = true
      if (queue.length > 0) processNext()
    }
  }

  Process {
    id: describeBackendProc
    command: [manager.backendPath, "describe"]
    running: true
    stdout: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0) {
        try {
          var description = JSON.parse(stdout.text)
          manager.backendSupported = description.supported === true
          manager.backendName = description.name || "Linux"
          manager.repoLabel = description.repoLabel || "System"
          manager.communityLabel = description.communityLabel || ""
          manager.hasCommunity = description.hasCommunity === true
          manager.systemUpdateDescription = description.systemDescription || "System upgrade"
          manager.systemUpdateRunningDescription = description.runningDescription || "Running system upgrade"
        } catch (error) {
          console.error("[UpdatesManager] Invalid backend description:", error)
        }
      }
      manager.backendReady = true
    }
  }

  Process {
    id: checkNativeProc
    command: [manager.backendPath, "check"]
    stdout: StdioCollector {}
    onExited: exitCode => {
      var repo = []
      var community = []
      if (exitCode === 0) {
        var lines = stdout.text.trim().split("\n").filter(function(line) { return line.length > 0 })
        for (var i = 0; i < lines.length; i++) {
          var fields = lines[i].split("\t")
          if (fields.length < 4) continue
          var update = {
            source: fields[0],
            name: fields[1],
            currentVersion: fields[2],
            newVersion: fields[3]
          }
          if (update.source === "repo") repo.push(update)
          else if (update.source === "community") community.push(update)
        }
      }
      manager.setSourceUpdates("repo", repo)
      manager.setSourceUpdates("community", community)
      checkFlatpakProc.running = true
    }
  }

  Process {
    id: checkFlatpakProc
    command: ["flatpak", "remote-ls", "--updates", "--app", "--columns=name,application,version"]
    stdout: StdioCollector {}
    onExited: exitCode => {
      var updates = []
      if (exitCode === 0) {
        var lines = stdout.text.trim().split("\n").filter(function(line) { return line.length > 0 })
        for (var i = 0; i < lines.length; i++) {
          var fields = lines[i].split("\t")
          if (fields.length < 2) continue
          updates.push({
            source: "flatpak",
            name: fields[0].trim(),
            appId: fields[1].trim(),
            currentVersion: "",
            newVersion: fields.length >= 3 ? fields[2].trim() : ""
          })
        }
      }
      manager.setSourceUpdates("flatpak", updates)
      manager.checking = false
    }
  }

  Process {
    id: singleProc
    property string pkgName: ""
    property string source: ""
    property string fromVersion: ""
    property string toVersion: ""
    stderr: StdioCollector {}
    onExited: exitCode => singleUpdateHelper.onFinished(pkgName, source, fromVersion, toVersion, exitCode)
  }

  Process {
    id: sourceUpdateProc
    property string source: ""
    stderr: StdioCollector {}
    onExited: exitCode => {
      var marked = Object.assign({}, manager.updatingPackages)
      var updates = manager.sourceUpdates(source)
      for (var i = 0; i < updates.length; i++) {
        delete marked[manager.packageKey(updates[i], source)]
      }
      manager.updatingPackages = marked

      if (exitCode === 0) {
        notifyProc.command = ["notify-send", "-a", "General", "System Updates", "Updated all " + source + " packages", "-i", "package-install"]
      } else {
        var body = "Failed to update " + source + " packages (exit " + exitCode + ")"
        var tail = manager.tailLines(stderr.text, 6)
        if (tail) body += "\n" + tail
        notifyProc.command = ["notify-send", "-a", "General", "-u", "critical", "System Updates", body, "-i", "dialog-error"]
      }
      notifyProc.running = true
      recheckTimer.restart()
    }
  }

  Process {
    id: systemUpdateProc
    stderr: StdioCollector {}
    onExited: exitCode => manager.onSystemUpdateComplete(exitCode === 0, exitCode)
  }

  Process { id: notifyProc }

  Timer {
    id: recheckTimer
    interval: 3000
    onTriggered: manager.checkUpdates()
  }

  Timer {
    interval: 5000
    running: true
    onTriggered: manager.checkUpdates()
  }

  Timer {
    interval: 3600000
    running: true
    repeat: true
    onTriggered: manager.checkUpdates()
  }
}
