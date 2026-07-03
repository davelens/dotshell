import QtQuick
import Quickshell.Io
import qs

// Single point of truth for module config persistence.
//
// Two modes:
//   - Adapter mode: assign a JsonAdapter to `adapter`. The file is loaded,
//     watched for external changes, and written back whenever adapter
//     properties change. A missing file is created from the adapter's
//     property defaults, so the QML defaults are the only defaults.
//   - Manual mode: leave `adapter` unset. Listen to `loaded(text)` and
//     persist with `save(object)`. A missing file emits loaded("") so the
//     caller can apply its own defaults.
//
// Scope picks the storage location and readiness gate:
//   - "profile": per-profile state, gated on DataManager.ready
//   - "general": profile-independent state, gated on DataManager.dataDirReady
Item {
  id: root

  required property string moduleId
  property string scope: "profile"
  property JsonAdapter adapter: null

  // Fires after every (re)load, including profile switches.
  signal loaded(string text)

  readonly property string path: scope === "general"
    ? DataManager.getGeneralStatePath(moduleId)
    : DataManager.getStatePath(moduleId)
  readonly property bool active: scope === "general"
    ? DataManager.dataDirReady
    : DataManager.ready

  function reload() { file.reload() }

  // Manual-mode save. Atomic: stage to .tmp then mv into place so a crash
  // mid-write can never leave a half-written file on disk.
  function save(config) {
    var json = JSON.stringify(config, null, 2)
    saveProc.command = ["sh", "-c",
      "cat > '" + path + ".tmp' << 'MODULE_CONFIG_EOF'\n" + json + "\nMODULE_CONFIG_EOF\n" +
      "mv -f '" + path + ".tmp' '" + path + "'"]
    saveProc.running = true
  }

  FileView {
    id: file
    path: root.active ? root.path : ""
    printErrors: false
    watchChanges: true
    adapter: root.adapter
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoaded: root.loaded(text())
    onLoadFailed: {
      if (root.adapter) writeAdapter()
      else root.loaded("")
    }
  }

  Process {
    id: saveProc
    onExited: code => {
      if (code !== 0) console.error("[ModuleConfig:" + root.moduleId + "] Failed to save config")
    }
  }
}
