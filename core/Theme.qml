pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
  id: theme

  // Backgrounds
  property color bgBase
  property color bgBaseAlt
  property color bgDeep
  property color bgCard
  property color bgCardHover
  property color bgBorder

  // Text
  property color textPrimary
  property color textSecondary
  property color textTertiary
  property color textMuted
  property color textSubtle

  // Semantic
  property color accent
  property color success
  property color warning
  property color danger
  property color focusRing
  property color activeIndicator
  property color overlay
  property color knob

  readonly property string themeFileName: GeneralSettings.theme + ".json"

  // User overrides in $XDG_DATA_HOME/dotshell/themes/ take precedence
  readonly property string userThemePath: DataManager.themesDir + "/"
    + themeFileName

  // Bundled themes in the shell config directory
  readonly property string bundledThemePath: Quickshell.shellDir + "/themes/"
    + themeFileName

  // Resolved path: user override if it exists, otherwise bundled
  property string resolvedThemePath: ""
  property bool pathReady: false

  // Pending paths for the current resolve operation — stored here so the
  // async SplitParser callback uses the exact paths the command was built with.
  property string _pendingUserPath: ""
  property string _pendingBundledPath: ""

  // Resolve which file to use: prefer user override, fall back to bundled.
  // Uses sh -c so we can do the conditional in a single process.
  Process {
    id: resolveProcess
    running: DataManager.dataDirReady && GeneralSettings.ready
    command: ["sh", "-c",
      "if [ -f '" + theme.userThemePath + "' ]; then echo user; else echo bundled; fi"]
    stdout: SplitParser {
      onRead: data => {
        theme.resolvedThemePath = data.trim() === "user"
          ? theme._pendingUserPath
          : theme._pendingBundledPath
        theme.pathReady = true
      }
    }
  }

  FileView {
    id: themeFile
    path: theme.pathReady ? theme.resolvedThemePath : ""
    watchChanges: true
    onFileChanged: reload()

    onLoaded: {
      theme.applyTheme(themeFile.text())
    }

    onLoadFailed: error => {
      console.error("[Theme] Failed to load theme file:", error)
    }
  }

  // Re-resolve when theme name changes (e.g. via IPC).
  // Compute paths directly from GeneralSettings.theme — the readonly binding
  // chain (themeFileName → userThemePath/bundledThemePath) may not have
  // propagated yet in this event loop tick.
  function resolveTheme() {
    pathReady = false
    resolvedThemePath = ""

    var fileName = GeneralSettings.theme + ".json"
    _pendingUserPath = DataManager.themesDir + "/" + fileName
    _pendingBundledPath = Quickshell.shellDir + "/themes/" + fileName

    resolveProcess.command = ["sh", "-c",
      "if [ -f '" + _pendingUserPath + "' ]; then echo user; else echo bundled; fi"]
    resolveProcess.running = true
  }

  // Initial boot: seed pending paths from the declarative bindings
  Component.onCompleted: {
    _pendingUserPath = userThemePath
    _pendingBundledPath = bundledThemePath
  }

  onThemeFileNameChanged: {
    if (DataManager.dataDirReady && GeneralSettings.ready)
      resolveTheme()
  }

  function applyTheme(text) {
    if (!text || text.trim() === "") return

    try {
      var t = JSON.parse(text)

      bgBase = t.bgBase
      bgBaseAlt = t.bgBaseAlt
      bgDeep = t.bgDeep
      bgCard = t.bgCard
      bgCardHover = t.bgCardHover
      bgBorder = t.bgBorder

      textPrimary = t.textPrimary
      textSecondary = t.textSecondary
      textTertiary = t.textTertiary
      textMuted = t.textMuted
      textSubtle = t.textSubtle

      accent = t.accent
      success = t.success
      warning = t.warning
      danger = t.danger
      focusRing = t.focusRing
      activeIndicator = t.activeIndicator
      overlay = t.overlay
      knob = t.knob
    } catch (e) {
      console.error("[Theme] Failed to parse theme:", e)
    }
  }
}
