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

  // Resolved path to the active theme JSON file
  readonly property string themePath: Quickshell.shellDir + "/themes/"
    + GeneralSettings.theme + ".json"

  FileView {
    id: themeFile
    path: GeneralSettings.ready ? theme.themePath : ""
    watchChanges: true
    onFileChanged: reload()

    onLoaded: {
      theme.applyTheme(themeFile.text())
    }

    onLoadFailed: error => {
      console.error("[Theme] Failed to load theme file:", error)
    }
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
