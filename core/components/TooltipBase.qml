import Quickshell
import QtQuick
import "../.."

// Reusable tooltip base for hover/focus info popups. Provides standard
// anchoring, background color, border, and auto-sizing with padding.
//
// Usage:
//   TooltipBase {
//     anchorItem: someItem
//     visible: hoverArea.containsMouse
//     Text { text: "Hello" }
//   }
//
// Content is placed inside a centered Item. Override implicitWidth /
// implicitHeight for fixed sizing (e.g. wider network tooltips).
PopupWindow {
  id: tooltip

  required property Item anchorItem

  // Padding around content (horizontal and vertical)
  property int horizontalPadding: 24
  property int verticalPadding: 16

  default property alias content: contentItem.data

  anchor.item: anchorItem
  anchor.edges: Edges.Bottom | Edges.Right
  anchor.gravity: Edges.Bottom | Edges.Left
  anchor.margins.bottom: -10

  implicitWidth: contentItem.childrenRect.width + horizontalPadding
  implicitHeight: contentItem.childrenRect.height + verticalPadding
  color: Colors.crust

  // Border
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: Colors.surface2
    z: 100
  }

  // Content container
  Item {
    id: contentItem
    anchors.centerIn: parent
    width: tooltip.width - tooltip.horizontalPadding
    height: contentItem.childrenRect.height
  }
}
