import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  property bool showInBar: ScreenRecordingManager.isRecording

  icon: "\u{f044a}"
  iconColor: Theme.danger

  onClicked: ScreenRecordingManager.stopRecording()
}
