import QtQuick
import qs

// Keep discovery and the publisher IPC active when the bar segment is disabled.
QtObject {
  readonly property int keepAlive: AiAgentsMonitorManager.totalCount
}
