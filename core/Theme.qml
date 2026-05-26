pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

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
  readonly property string userThemePath: DataManager.themesDir + "/" + themeFileName

  // Bundled themes in the shell config directory
  readonly property string bundledThemePath: Quickshell.shellDir + "/themes/" + themeFileName

  // Gate: both data dir and general settings must be ready before we look up files
  readonly property bool pathsReady: DataManager.dataDirReady && GeneralSettings.ready

  // Track load state of both candidates so resolveAndApply() can pick the user
  // override when present and fall back to bundled otherwise. Flags reset on
  // theme name change so stale text from a previous theme can't leak through.
  property bool userLoaded: false
  property bool bundledLoaded: false

  onThemeFileNameChanged: {
    userLoaded = false
    bundledLoaded = false
  }

  FileView {
    id: userTheme
    path: theme.pathsReady ? theme.userThemePath : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      theme.userLoaded = true
      theme.resolveAndApply()
    }
    onLoadFailed: {
      theme.userLoaded = false
      theme.resolveAndApply()
    }
  }

  FileView {
    id: bundledTheme
    path: theme.pathsReady ? theme.bundledThemePath : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      theme.bundledLoaded = true
      theme.resolveAndApply()
    }
    onLoadFailed: error => {
      theme.bundledLoaded = false
      console.error("[Theme] Failed to load bundled theme:", theme.bundledThemePath, error)
    }
  }

  function resolveAndApply() {
    if (userLoaded) applyTheme(userTheme.text())
    else if (bundledLoaded) applyTheme(bundledTheme.text())
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
