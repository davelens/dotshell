import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  property bool showInBar: RecordingManager.isRecording

  icon: "\u{f044a}"
  iconColor: Theme.danger

  onClicked: RecordingManager.stopRecording()
}
