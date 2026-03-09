pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
  id: theme

  // Defaults (Catppuccin Mocha) — used as fallback when no theme file
  // is loaded or when a theme file is missing a key.
  readonly property color _bgBase: "#1e1e2e"
  readonly property color _bgBaseAlt: "#181825"
  readonly property color _bgDeep: "#11111b"
  readonly property color _bgCard: "#313244"
  readonly property color _bgCardHover: "#45475a"
  readonly property color _bgBorder: "#585b70"
  readonly property color _textPrimary: "#cdd6f4"
  readonly property color _textSecondary: "#a6adc8"
  readonly property color _textTertiary: "#bac2de"
  readonly property color _textMuted: "#6c7086"
  readonly property color _textSubtle: "#7f849c"
  readonly property color _accent: "#89b4fa"
  readonly property color _success: "#a6e3a1"
  readonly property color _warning: "#f9e2af"
  readonly property color _danger: "#f38ba8"
  readonly property color _focusRing: "#fab387"
  readonly property color _activeIndicator: "#94e2d5"
  readonly property color _overlay: "#80000000"

  // Active values (loaded from theme file, fallback to defaults)
  // Backgrounds
  property color bgBase: _bgBase
  property color bgBaseAlt: _bgBaseAlt
  property color bgDeep: _bgDeep
  property color bgCard: _bgCard
  property color bgCardHover: _bgCardHover
  property color bgBorder: _bgBorder

  // Text
  property color textPrimary: _textPrimary
  property color textSecondary: _textSecondary
  property color textTertiary: _textTertiary
  property color textMuted: _textMuted
  property color textSubtle: _textSubtle

  // Semantic
  property color accent: _accent
  property color success: _success
  property color warning: _warning
  property color danger: _danger
  property color focusRing: _focusRing
  property color activeIndicator: _activeIndicator
  property color overlay: _overlay

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
      console.warn("[Theme] Failed to load theme file:", error)
      theme.resetToDefaults()
    }
  }

  function applyTheme(text) {
    if (!text || text.trim() === "") {
      resetToDefaults()
      return
    }

    try {
      var t = JSON.parse(text)

      bgBase = t.bgBase || _bgBase
      bgBaseAlt = t.bgBaseAlt || _bgBaseAlt
      bgDeep = t.bgDeep || _bgDeep
      bgCard = t.bgCard || _bgCard
      bgCardHover = t.bgCardHover || _bgCardHover
      bgBorder = t.bgBorder || _bgBorder

      textPrimary = t.textPrimary || _textPrimary
      textSecondary = t.textSecondary || _textSecondary
      textTertiary = t.textTertiary || _textTertiary
      textMuted = t.textMuted || _textMuted
      textSubtle = t.textSubtle || _textSubtle

      accent = t.accent || _accent
      success = t.success || _success
      warning = t.warning || _warning
      danger = t.danger || _danger
      focusRing = t.focusRing || _focusRing
      activeIndicator = t.activeIndicator || _activeIndicator
      overlay = t.overlay || _overlay
    } catch (e) {
      console.error("[Theme] Failed to parse theme:", e)
      resetToDefaults()
    }
  }

  function resetToDefaults() {
    bgBase = _bgBase
    bgBaseAlt = _bgBaseAlt
    bgDeep = _bgDeep
    bgCard = _bgCard
    bgCardHover = _bgCardHover
    bgBorder = _bgBorder

    textPrimary = _textPrimary
    textSecondary = _textSecondary
    textTertiary = _textTertiary
    textMuted = _textMuted
    textSubtle = _textSubtle

    accent = _accent
    success = _success
    warning = _warning
    danger = _danger
    focusRing = _focusRing
    activeIndicator = _activeIndicator
    overlay = _overlay
  }
}
