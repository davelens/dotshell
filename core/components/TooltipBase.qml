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
// Content is placed inside a centered Item. Set fixedWidth for tooltips
// that need parent-based content sizing (e.g. text eliding).
PopupWindow {
  id: tooltip

  required property Item anchorItem

  // Set to a fixed width to enable parent-based content sizing (e.g. text
  // eliding). When -1, the tooltip auto-sizes from its content.
  property int fixedWidth: -1

  // Padding around content (horizontal and vertical)
  property int horizontalPadding: 24
  property int verticalPadding: 16

  default property alias content: contentItem.data

  anchor.item: anchorItem
  anchor.edges: Edges.Bottom | Edges.Right
  anchor.gravity: Edges.Bottom | Edges.Left
  anchor.margins.bottom: -10

  implicitWidth: fixedWidth > 0 ? fixedWidth
    : contentItem.childrenRect.width + horizontalPadding
  implicitHeight: contentItem.childrenRect.height + verticalPadding
  color: Theme.bgDeep

  // Border
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: Theme.bgBorder
    z: 100
  }

  // Content container. When fixedWidth is set, width derives from the
  // tooltip so children can use parent.width for text eliding. Otherwise
  // width follows childrenRect to avoid a circular binding.
  Item {
    id: contentItem
    anchors.centerIn: parent
    width: tooltip.fixedWidth > 0
      ? tooltip.width - tooltip.horizontalPadding
      : contentItem.childrenRect.width
    height: contentItem.childrenRect.height
  }
}
