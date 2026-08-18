pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Manages the data directory at $XDG_DATA_HOME/dotshell/.
// Provides profile-aware state paths (consumed by ModuleConfig).
//
// Bootstrap sequence:
//   1. Creates dataDir and themesDir (mkdir -p)
//   2. Migrates renamed general state, then dataDirReady = true
//   3. GeneralSettings loads general.json, calls setActiveProfile(dir)
//   4. Creates the profile directory and migrates renamed profile state
//   5. ready = true (all modules can now load state)
Singleton {
  id: dataManager

  readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/dotshell"
  readonly property string themesDir: dataDir + "/themes"

  // Active profile directory name (set by GeneralSettings)
  property string activeProfileDir: ""
  readonly property string profileDir: dataDir + "/" + activeProfileDir

  // Stage 1: data directory and themes directory exist
  property bool dataDirsCreated: false
  property bool dataDirReady: false

  // Stage 2: profile directory exists, all state paths are valid
  property bool ready: false
  property bool profileDirReady: false

  Connections {
    target: ModuleRegistry
    function onReadyChanged() {
      if (ModuleRegistry.ready) {
        dataManager.migrateGeneralState()
        dataManager.migrateProfileState()
      }
    }
  }

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
    profileDirReady = false
    activeProfileDir = dir
    ensureProfileDir.command = ["mkdir", "-p", dataManager.profileDir]
    ensureProfileDir.running = true
  }

  function migrationCommand(stateDir, suffix, mappings) {
    var command = ["bash", Quickshell.shellDir + "/core/migrate-module-state", stateDir, suffix]
    for (var i = 0; i < mappings.length; i++) {
      command.push(mappings[i].oldId, mappings[i].newId)
    }
    return command
  }

  function migrateGeneralState() {
    if (!dataDirsCreated || !ModuleRegistry.ready || dataDirReady || generalStateMigration.running) return

    var mappings = ModuleRegistry.getRenameMappings()
    if (mappings.length === 0) {
      dataDirReady = true
      return
    }

    generalStateMigration.command = migrationCommand(dataDir, "-general", mappings)
    generalStateMigration.running = true
  }

  function migrateProfileState() {
    if (!profileDirReady || !ModuleRegistry.ready || profileStateMigration.running) return

    var mappings = ModuleRegistry.getRenameMappings()
    if (mappings.length === 0) {
      ready = true
      return
    }

    profileStateMigration.command = migrationCommand(profileDir, "", mappings)
    profileStateMigration.running = true
  }

  Component.onCompleted: {
    ensureDataDir.running = true
  }

  // Stage 1: create dataDir and themesDir
  Process {
    id: ensureDataDir
    command: ["mkdir", "-p", dataManager.dataDir, dataManager.themesDir]
    onExited: {
      dataManager.dataDirsCreated = true
      dataManager.migrateGeneralState()
    }
  }

  // Stage 2: create profile directory
  Process {
    id: ensureProfileDir
    onExited: {
      dataManager.profileDirReady = true
      dataManager.migrateProfileState()
    }
  }

  Process {
    id: generalStateMigration
    onExited: exitCode => {
      if (exitCode === 0) dataManager.dataDirReady = true
      else console.error("[DataManager] Failed to migrate renamed general module state")
    }
  }

  Process {
    id: profileStateMigration
    onExited: exitCode => {
      if (exitCode === 0) dataManager.ready = true
      else console.error("[DataManager] Failed to migrate renamed profile module state")
    }
  }
}
