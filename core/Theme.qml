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

  readonly property string themeFileName: GeneralSettings.theme + ".json"

  // User overrides in $XDG_DATA_HOME/dotshell/themes/ take precedence
  readonly property string userThemePath: DataManager.dataDir + "/themes/"
    + themeFileName

  // Bundled themes in the shell config directory
  readonly property string bundledThemePath: Quickshell.shellDir + "/themes/"
    + themeFileName

  // Resolved path: user override if it exists, otherwise bundled
  property string resolvedThemePath: ""
  property bool pathReady: false

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
          ? theme.userThemePath
          : theme.bundledThemePath
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

  // Re-resolve when theme name changes (e.g. via IPC)
  onThemeFileNameChanged: {
    pathReady = false
    resolvedThemePath = ""
    if (DataManager.dataDirReady && GeneralSettings.ready)
      resolveProcess.running = true
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
    } catch (e) {
      console.error("[Theme] Failed to parse theme:", e)
    }
  }
}
