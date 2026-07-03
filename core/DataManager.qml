pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Manages the data directory at $XDG_DATA_HOME/dotshell/.
// Provides profile-aware state paths (consumed by ModuleConfig).
//
// Bootstrap sequence:
//   1. Creates dataDir and themesDir (mkdir -p)
//   2. dataDirReady = true
//   3. GeneralSettings loads general.json, calls setActiveProfile(dir)
//   4. Creates profile directory
//   5. ready = true (all modules can now load state)
Singleton {
  id: dataManager

  readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/dotshell"
  readonly property string themesDir: dataDir + "/themes"

  // Active profile directory name (set by GeneralSettings)
  property string activeProfileDir: ""
  readonly property string profileDir: dataDir + "/" + activeProfileDir

  // Stage 1: data directory and themes directory exist
  property bool dataDirReady: false

  // Stage 2: profile directory exists, all state paths are valid
  property bool ready: false

  // Get the state file path for a module within the active profile
  function getStatePath(moduleId) {
    return profileDir + "/" + moduleId + ".json"
  }

  // Get the general (profile-independent) state file path for a module.
  // Lives at dataDir root, not inside a profile directory.
  // Gated on dataDirReady (stage 1), not ready (stage 2).
  function getGeneralStatePath(moduleId) {
    return dataDir + "/" + moduleId + "-general.json"
  }

  // Called by GeneralSettings once the active profile is known.
  // Also called when switching profiles (ready cycles false -> true).
  function setActiveProfile(dir) {
    ready = false
    activeProfileDir = dir
    ensureProfileDir.command = ["mkdir", "-p", dataManager.profileDir]
    ensureProfileDir.running = true
  }

  Component.onCompleted: {
    ensureDataDir.running = true
  }

  // Stage 1: create dataDir and themesDir
  Process {
    id: ensureDataDir
    command: ["mkdir", "-p", dataManager.dataDir, dataManager.themesDir]
    onExited: {
      dataManager.dataDirReady = true
    }
  }

  // Stage 2: create profile directory
  Process {
    id: ensureProfileDir
    onExited: {
      dataManager.ready = true
    }
  }
}
