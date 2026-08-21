import QtQuick
import qs

QtObject {
  // Keep the display manager active even when its popup has never been opened.
  property var manager: DisplayManager
}
