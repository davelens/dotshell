import Quickshell
import qs

// Host for a module's popup window. shell.qml injects `moduleId` from the
// module manifest at creation time, so the id is never restated in module
// QML. Declare a PopupBase child as the delegate; it is instantiated on
// the screen selected when the popup opens.
Variants {
  id: root

  required property string moduleId

  readonly property bool isOpen: PopupManager.isOpen(moduleId)

  model: isOpen && PopupManager.targetScreen
         ? [PopupManager.targetScreen] : []
}
