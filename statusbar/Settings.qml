import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

Item {
  id: settingsRoot
  anchors.fill: parent

  // Search query passed from SettingsPanel
  property string searchQuery: ""

  // Drag state
  property string draggedItemId: ""
  property string draggedFromSection: ""
  property bool isDragging: false
  property string dropSection: ""
  property int dropIndex: -1
  property real dragMouseY: 0
  property string draggedItemName: ""
  property string draggedItemIcon: ""

  function highlightText(text, query) {
    return Theme.highlightText(text, query)
  }

  function startDrag(itemId, fromSection) {
    draggedItemId = itemId
    draggedFromSection = fromSection
    isDragging = true
    dropSection = ""
    dropIndex = -1
    var mod = ModuleRegistry.getModule(itemId)
    draggedItemName = mod ? mod.name : itemId
    draggedItemIcon = mod ? mod.icon : "?"
  }

  function endDrag() {
    if (draggedItemId && dropSection && dropIndex >= 0) {
      StatusbarManager.moveItem(draggedItemId, dropSection, dropIndex)
    }
    draggedItemId = ""
    draggedFromSection = ""
    isDragging = false
    dropSection = ""
    dropIndex = -1
    dragMouseY = 0
    draggedItemName = ""
    draggedItemIcon = ""
  }

  // Resolve drop target from global mouse Y within the scroll content
  function resolveDropTarget(globalMouseY) {
    // Map mouse position to scroll content coordinates
    var contentY = globalMouseY + scrollView.contentItem.contentY

    // Check each section
    var sections = [leftSection, centerSection, rightSection]

    for (var s = 0; s < sections.length; s++) {
      var section = sections[s]
      var sectionPos = section.mapToItem(scrollContent, 0, 0)
      var sectionTop = sectionPos.y
      var sectionBottom = sectionTop + section.height

      if (contentY >= sectionTop && contentY <= sectionBottom) {
        if (section.sectionItems.length === 0) {
          dropSection = section.sectionName
          dropIndex = 0
          return
        }

        for (var i = 0; i < section.sectionItems.length; i++) {
          var rowWrapper = section.rowAt(i)
          if (!rowWrapper || rowWrapper.height === 0) continue

          var rowPos = rowWrapper.mapToItem(scrollContent, 0, 0)
          var rowMid = rowPos.y + rowWrapper.height / 2

          if (contentY < rowMid) {
            dropSection = section.sectionName
            dropIndex = i
            return
          }
        }

        // Below all items in this section
        dropSection = section.sectionName
        dropIndex = section.sectionItems.length
        return
      }
    }
  }

  // Ghost row that follows the cursor during drag
  Rectangle {
    id: dragGhost
    visible: settingsRoot.isDragging
    z: 200
    x: 12
    y: settingsRoot.dragMouseY - height / 2
    width: settingsRoot.width - 24
    height: 48
    radius: 6
    color: Theme.bgCard
    opacity: 0.85
    border.width: 1
    border.color: Theme.accent

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: settingsRoot.draggedItemIcon
        color: Theme.accent
        font.pixelSize: 18
        font.family: "Symbols Nerd Font"
        width: 24
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: settingsRoot.draggedItemName
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 14
      }
    }
  }

  ScrollView {
    id: scrollView
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

    // Disable scroll interaction during drag to prevent it from stealing events
    Binding {
      target: scrollView.contentItem
      property: "interactive"
      value: false
      when: settingsRoot.isDragging
      restoreMode: Binding.RestoreBindingOrValue
    }

    Column {
      id: scrollContent
      width: parent.width
      spacing: 24

      // Header
      Text {
        text: "Status Bar"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 24
        font.bold: true
      }

      // Bar margins
      Column {
        width: parent.width
        spacing: 8

        TitleText {
          text: settingsRoot.highlightText("Bar Margins", settingsRoot.searchQuery)
          textFormat: Text.RichText
        }

        Row {
          width: parent.width
          spacing: 24

          BarMarginControl {
            label: "Left"
            value: StatusbarManager.barMargins.left
            onValueModified: value => StatusbarManager.setBarMargins(value, StatusbarManager.barMargins.right)
          }

          BarMarginControl {
            label: "Right"
            value: StatusbarManager.barMargins.right
            onValueModified: value => StatusbarManager.setBarMargins(StatusbarManager.barMargins.left, value)
          }
        }
      }

      // Popup stem toggle
      Row {
        spacing: 12

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: settingsRoot.highlightText("Popup stem connector", settingsRoot.searchQuery)
          textFormat: Text.RichText
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: 14
        }

        SwitchToggle {
          anchors.verticalCenter: parent.verticalCenter
          checked: StatusbarManager.popupStem
          onClicked: StatusbarManager.togglePopupStem()
        }
      }

      Rectangle { width: parent.width; height: 1; color: Theme.bgCardHover }

      // Left section
      StatusbarSection {
        id: leftSection
        sectionName: "left"
        title: "Left Section"
        sectionItems: StatusbarManager.leftItems
      }

      Rectangle { width: parent.width; height: 1; color: Theme.bgCardHover }

      // Center section
      StatusbarSection {
        id: centerSection
        sectionName: "center"
        title: "Center Section"
        sectionItems: StatusbarManager.centerItems
      }

      Rectangle { width: parent.width; height: 1; color: Theme.bgCardHover }

      // Right section
      StatusbarSection {
        id: rightSection
        sectionName: "right"
        title: "Right Section"
        sectionItems: StatusbarManager.rightItems
      }

      // Separator line
      Rectangle {
        width: parent.width
        height: 1
        color: Theme.bgBorder
      }

      // Reset button (with margin for focus ring visibility)
      Item {
        width: parent.width
        height: 36

        FocusButton {
          x: 2
          text: "Reset to Defaults"
          width: 140
          height: 32
          backgroundColor: Theme.bgCardHover
          hoverColor: Theme.bgBorder
          onClicked: StatusbarManager.resetToDefaults()
        }
      }
    }
  }

  component BarMarginControl: Row {
    id: marginControl
    property string label
    property int value
    signal valueModified(int value)

    spacing: 8

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: marginControl.label + ":"
      color: Theme.textPrimary
      font.family: Theme.fontFamily
      font.pixelSize: 13
    }

    SpinBox {
      id: marginSpin
      from: 0
      to: 100
      value: marginControl.value
      editable: true
      width: 80

      onValueModified: marginControl.valueModified(value)

      background: Rectangle {
        color: Theme.bgCard
        radius: 4
      }

      contentItem: TextInput {
        z: 2
        text: marginSpin.textFromValue(marginSpin.value, marginSpin.locale)
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 13
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        readOnly: !marginSpin.editable
        validator: marginSpin.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
      }

      up.indicator: Rectangle {
        x: parent.width - width
        height: parent.height
        width: 24
        color: marginSpin.up.pressed ? Theme.bgBorder : Theme.bgCardHover
        radius: 4

        Text {
          anchors.centerIn: parent
          text: "+"
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: 14
        }
      }

      down.indicator: Rectangle {
        x: 0
        height: parent.height
        width: 24
        color: marginSpin.down.pressed ? Theme.bgBorder : Theme.bgCardHover
        radius: 4

        Text {
          anchors.centerIn: parent
          text: "-"
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: 14
        }
      }
    }
  }

  component StatusbarSection: Column {
    id: sectionRoot
    property string sectionName
    property string title
    property var sectionItems

    width: parent.width
    spacing: 8

    function rowAt(index) {
      return itemRepeater.itemAt(index)
    }

    TitleText {
      text: settingsRoot.highlightText(sectionRoot.title, settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Column {
      width: parent.width
      spacing: 0

      Repeater {
        id: itemRepeater
        model: sectionRoot.sectionItems

        ItemRowWrapper {
          required property var modelData
          required property int index
          item: modelData
          itemIndex: index
          section: sectionRoot.sectionName
          sectionItems: sectionRoot.sectionItems
        }
      }
    }

    EmptyDropZone {
      sectionName: sectionRoot.sectionName
      sectionItems: sectionRoot.sectionItems
    }
  }

  // Empty section drop zone
  component EmptyDropZone: Item {
    property string sectionName
    property var sectionItems

    width: parent.width
    height: visible ? 56 : 0
    visible: sectionItems.length === 0

    Rectangle {
      anchors.fill: parent
      radius: 6
      color: "transparent"
      border.width: 2
      border.color: settingsRoot.isDragging && settingsRoot.dropSection === sectionName
                      ? Theme.accent : Theme.bgBorder
      visible: settingsRoot.isDragging
    }

    Text {
      anchors.centerIn: parent
      text: settingsRoot.isDragging ? "Drop here" : ("No items in " + sectionName + " section")
      color: Theme.textMuted
      font.family: Theme.fontFamily
      font.pixelSize: 13
    }
  }

  // Wrapper around each item row that includes the drop indicator
  component ItemRowWrapper: Column {
    id: wrapper
    property var item
    property int itemIndex
    property string section
    property var sectionItems

    width: parent.width

    // Drop indicator above this row
    Rectangle {
      width: parent.width
      height: 3
      radius: 2
      color: Theme.accent
      visible: settingsRoot.isDragging
                && settingsRoot.dropSection === wrapper.section
                && settingsRoot.dropIndex === wrapper.itemIndex
                && settingsRoot.draggedItemId !== wrapper.item.id
    }

    Item { width: 1; height: 4 }

    StatusbarItemRow {
      item: wrapper.item
      itemIndex: wrapper.itemIndex
      section: wrapper.section
    }

    // Drop indicator after last item
    Rectangle {
      width: parent.width
      height: 3
      radius: 2
      color: Theme.accent
      visible: settingsRoot.isDragging
                && settingsRoot.dropSection === wrapper.section
                && settingsRoot.dropIndex === wrapper.itemIndex + 1
                && wrapper.itemIndex === wrapper.sectionItems.length - 1
                && settingsRoot.draggedItemId !== wrapper.item.id
    }
  }

  // Item row
  component StatusbarItemRow: Rectangle {
    id: itemRow
    property var item
    property int itemIndex
    property string section

    width: parent.width
    height: 56
    radius: 6
    color: item.enabled ? Theme.bgCard : Theme.bgBaseAlt
    opacity: settingsRoot.draggedItemId === item.id ? 0.3 : 1.0

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      // Drag handle
      Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 32

        Text {
          anchors.centerIn: parent
          text: "󰇙"
          color: dragArea.pressed ? Theme.accent : (dragArea.containsMouse ? Theme.textPrimary : Theme.textMuted)
          font.pixelSize: 16
          font.family: "Symbols Nerd Font"
        }

        MouseArea {
          id: dragArea
          anchors.fill: parent
          hoverEnabled: true
          preventStealing: true
          cursorShape: settingsRoot.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

          onPressed: mouse => {
            settingsRoot.startDrag(item.id, section)
            var mapped = mapToItem(settingsRoot, mouse.x, mouse.y)
            settingsRoot.dragMouseY = mapped.y
            settingsRoot.resolveDropTarget(mapped.y)
          }

          onPositionChanged: mouse => {
            if (!settingsRoot.isDragging) return
            var mapped = mapToItem(settingsRoot, mouse.x, mouse.y)
            settingsRoot.dragMouseY = mapped.y
            settingsRoot.resolveDropTarget(mapped.y)
          }

          onReleased: {
            settingsRoot.endDrag()
          }
        }
      }

      // Module icon
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: {
          var mod = ModuleRegistry.getModule(item.id)
          return mod ? mod.icon : "?"
        }
        color: item.enabled ? Theme.accent : Theme.textMuted
        font.pixelSize: 18
        font.family: "Symbols Nerd Font"
        width: 24
        horizontalAlignment: Text.AlignHCenter
      }

      // Module name
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: {
          var mod = ModuleRegistry.getModule(item.id)
          return mod ? mod.name : item.id
        }
        color: item.enabled ? Theme.textPrimary : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 14
        width: 120
      }

      // Margin inputs
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "L:"
          color: Theme.textMuted
          font.family: Theme.fontFamily
          font.pixelSize: 11
        }

        Rectangle {
          width: 40
          height: 24
          radius: 4
          color: Theme.bgCardHover
          border.width: leftMarginInput.activeFocus ? 2 : 0
          border.color: Theme.focusRing

          TextInput {
            id: leftMarginInput
            anchors.fill: parent
            anchors.margins: 4
            text: item.marginLeft
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            activeFocusOnTab: true
            selectByMouse: true
            validator: IntValidator { bottom: 0; top: 100 }
            onActiveFocusChanged: if (activeFocus) selectAll()
            onEditingFinished: {
              StatusbarManager.setMargins(item.id, parseInt(text) || 0, item.marginRight)
            }
            Keys.onReturnPressed: focus = false
            Keys.onEnterPressed: focus = false
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "R:"
          color: Theme.textMuted
          font.family: Theme.fontFamily
          font.pixelSize: 11
        }

        Rectangle {
          width: 40
          height: 24
          radius: 4
          color: Theme.bgCardHover
          border.width: rightMarginInput.activeFocus ? 2 : 0
          border.color: Theme.focusRing

          TextInput {
            id: rightMarginInput
            anchors.fill: parent
            anchors.margins: 4
            text: item.marginRight
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            activeFocusOnTab: true
            selectByMouse: true
            validator: IntValidator { bottom: 0; top: 100 }
            onActiveFocusChanged: if (activeFocus) selectAll()
            onEditingFinished: {
              StatusbarManager.setMargins(item.id, item.marginLeft, parseInt(text) || 0)
            }
            Keys.onReturnPressed: focus = false
            Keys.onEnterPressed: focus = false
          }
        }
      }
    }

    // Enable toggle
    SwitchToggle {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      checked: item.enabled
      onClicked: StatusbarManager.toggleItem(item.id)
    }
  }
}
