import QtQuick

// Keep IPC available when the bar button is disabled.
QtObject {
  readonly property bool keepAlive: IdleInhibitorManager.inhibited
}
