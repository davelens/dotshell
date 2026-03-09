pragma Singleton
import QtQuick

// Default theme: Catppuccin Mocha
// https://github.com/catppuccin/catppuccin
QtObject {
  // Backgrounds
  readonly property color bgBase: "#1e1e2e"
  readonly property color bgBaseAlt: "#181825"
  readonly property color bgDeep: "#11111b"
  readonly property color bgCard: "#313244"
  readonly property color bgCardHover: "#45475a"
  readonly property color bgBorder: "#585b70"

  // Text
  readonly property color textPrimary: "#cdd6f4"
  readonly property color textSecondary: "#a6adc8"
  readonly property color textTertiary: "#bac2de"
  readonly property color textMuted: "#6c7086"
  readonly property color textSubtle: "#7f849c"

  // Semantic
  readonly property color accent: "#89b4fa"
  readonly property color success: "#a6e3a1"
  readonly property color warning: "#f9e2af"
  readonly property color danger: "#f38ba8"
  readonly property color focusRing: "#fab387"
  readonly property color activeIndicator: "#94e2d5"
  readonly property color overlay: "#80000000"
}
