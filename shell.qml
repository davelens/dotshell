//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "core"
import "core/components"

ShellRoot {
  id: root

  SettingsPanel {}

  property bool _componentsLoaded: false

  // Dynamically load module popups and root components from manifests.
  // Guarded with _componentsLoaded so a future ModuleRegistry.ready re-trigger
  // (e.g. profile switch causing rediscovery) does not double-instantiate.
  Connections {
    target: ModuleRegistry
    function onReadyChanged() {
      if (!ModuleRegistry.ready || root._componentsLoaded) return
      root._componentsLoaded = true

      // Module popups (e.g. volume, bluetooth, wireless popup windows)
      var popups = ModuleRegistry.getPopupModules()
      for (var i = 0; i < popups.length; i++) {
        var popupPath = ModuleRegistry.getPopupRelPath(popups[i].id)
        var popupComp = Qt.createComponent(popupPath)
        if (popupComp.status === Component.Ready) {
          // Inject the manifest id so popups never restate it
          popupComp.createObject(root, { moduleId: popups[i].id })
        } else {
          console.error("[shell] Failed to load popup:", popupPath, popupComp.errorString())
        }
      }

      // Root components (e.g. notification panel, notification popups)
      var rootComps = ModuleRegistry.getRootComponents()
      for (var j = 0; j < rootComps.length; j++) {
        var rootPath = ModuleRegistry.getRelPath(rootComps[j].module, rootComps[j].file)
        var rootComp = Qt.createComponent(rootPath)
        if (rootComp.status === Component.Ready) {
          rootComp.createObject(root)
        } else {
          console.error("[shell] Failed to load root component:", rootPath, rootComp.errorString())
        }
      }
    }
  }

  // Makes the statusbar only appear on primary screen
  Variants {
    model: ScreenManager.primaryScreen && StatusbarManager.ready ? [ScreenManager.primaryScreen] : []

    PanelWindow {
      required property var modelData

      id: panel
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 32
      color: Theme.bgDeep

      WlrLayershell.namespace: "dotshell-bar"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: barFocusActive
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      // Modules that use PanelWindow popups (derived from ModuleRegistry)
      property var popupModules: ModuleRegistry.ready ? ModuleRegistry.getPopupModuleIds() : []

      // Bar focus mode state (unified index across left, center, right sections)
      property bool barFocusActive: false
      property int barFocusIndex: 0

      // Enabled items per section
      property var leftEnabledItems: StatusbarManager.leftItems.filter(function(i) { return i.enabled })
      property var centerEnabledItems: StatusbarManager.centerItems.filter(function(i) { return i.enabled })
      property var rightEnabledItems: StatusbarManager.rightItems.filter(function(i) { return i.enabled })

      // Unified index offsets: [left 0..L-1] [center L..L+C-1] [right L+C..L+C+R-1]
      property int centerOffset: leftEnabledItems.length
      property int rightOffset: leftEnabledItems.length + centerEnabledItems.length
      property int totalFocusItems: leftEnabledItems.length + centerEnabledItems.length + rightEnabledItems.length

      // Modules to skip during keyboard navigation (declared via skipBarFocus in module.json)
      property var skipModules: ModuleRegistry.ready ? ModuleRegistry.getSkipBarFocusIds() : []

      // Resolve a unified index to its section and local index
      function resolveSection(idx) {
        if (idx < centerOffset) return { section: "left", localIndex: idx, items: leftEnabledItems }
        if (idx < rightOffset) return { section: "center", localIndex: idx - centerOffset, items: centerEnabledItems }
        return { section: "right", localIndex: idx - rightOffset, items: rightEnabledItems }
      }

      function sectionFor(name) {
        if (name === "left") return leftSection
        if (name === "center") return centerSection
        return rightSection
      }

      function isFocusable(idx) {
        if (idx < 0 || idx >= totalFocusItems) return false
        var resolved = resolveSection(idx)
        if (skipModules.indexOf(resolved.items[resolved.localIndex].id) !== -1) return false
        var d = sectionFor(resolved.section).repeater.itemAt(resolved.localIndex)
        return d && d.visible
      }

      function nextFocusIndex(from) {
        for (var i = from + 1; i < totalFocusItems; i++) {
          if (isFocusable(i)) return i
        }
        return from
      }

      function prevFocusIndex(from) {
        for (var i = from - 1; i >= 0; i--) {
          if (isFocusable(i)) return i
        }
        return from
      }

      // Start at center, fall back to right, then left
      function firstFocusIndex() {
        for (var i = centerOffset; i < rightOffset; i++) {
          if (isFocusable(i)) return i
        }
        for (var i = rightOffset; i < totalFocusItems; i++) {
          if (isFocusable(i)) return i
        }
        for (var i = 0; i < centerOffset; i++) {
          if (isFocusable(i)) return i
        }
        return 0
      }

      // Update barFocused property on segments and focusLocalIndex on BarSections
      onBarFocusIndexChanged: updateSegmentFocus()
      onBarFocusActiveChanged: updateSegmentFocus()

      function updateSegmentFocus() {
        var resolved = barFocusActive ? resolveSection(barFocusIndex) : null

        leftSection.focusLocalIndex = (resolved && resolved.section === "left") ? resolved.localIndex : -1
        centerSection.focusLocalIndex = (resolved && resolved.section === "center") ? resolved.localIndex : -1
        rightSection.focusLocalIndex = (resolved && resolved.section === "right") ? resolved.localIndex : -1

        applyBarFocusedFlag(leftSection, leftEnabledItems.length, 0)
        applyBarFocusedFlag(centerSection, centerEnabledItems.length, centerOffset)
        applyBarFocusedFlag(rightSection, rightEnabledItems.length, rightOffset)
      }

      function applyBarFocusedFlag(sect, count, offset) {
        for (var i = 0; i < count; i++) {
          var item = sect.itemAt(i)
          if (item && item.hasOwnProperty("barFocused")) {
            item.barFocused = barFocusActive && barFocusIndex === (i + offset)
          }
        }
      }

      // Exit bar focus when a popup opens
      Connections {
        target: PopupManager
        function onActivePopupChanged() {
          if (PopupManager.activePopup !== "") {
            panel.barFocusActive = false
          }
        }
      }

      // Exit bar focus when an overlay (panel, power menu, settings) opens
      Connections {
        target: OverlayManager
        function onOverlayOpenChanged() {
          if (OverlayManager.overlayOpen) {
            panel.barFocusActive = false
          }
        }
      }

      // Keyboard handling for bar focus mode
      contentItem {
        focus: panel.barFocusActive

        Keys.onPressed: function(event) {
          if (!panel.barFocusActive) return

          // Escape, q, or ctrl+[
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q
              || (event.key === Qt.Key_BracketLeft && (event.modifiers & Qt.ControlModifier))) {
            panel.barFocusActive = false
            event.accepted = true
          } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            panel.activateFocusedItem()
            event.accepted = true
          } else if (event.key === Qt.Key_L) {
            panel.barFocusIndex = panel.nextFocusIndex(panel.barFocusIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_H) {
            panel.barFocusIndex = panel.prevFocusIndex(panel.barFocusIndex)
            event.accepted = true
          }
        }
      }

      // Activate the currently focused bar item
      function activateFocusedItem() {
        if (barFocusIndex < 0 || barFocusIndex >= totalFocusItems) return

        var resolved = resolveSection(barFocusIndex)
        var moduleId = resolved.items[resolved.localIndex].id
        var sect = sectionFor(resolved.section)
        var delegate = sect.repeater.itemAt(resolved.localIndex)
        var wrapper = delegate ? delegate.children[1] : null
        var loaded = sect.itemAt(resolved.localIndex)

        // Compute anchor position for popups
        var anchorRight = panel.width - 10
        if (wrapper) {
          var mapped = wrapper.mapToItem(null, wrapper.width, 0)
          anchorRight = mapped.x
        }

        if (panel.popupModules.indexOf(moduleId) !== -1) {
          PopupManager.toggle(moduleId, panel.modelData, anchorRight)
          return
        }

        // Buttons without popups: trigger their clicked signal directly
        if (ModuleRegistry.isButton(moduleId)) {
          if (loaded && loaded.clicked) loaded.clicked()
          return
        }

        // Segments with activate (e.g. media play/pause)
        if (loaded && typeof loaded.activate === "function") {
          loaded.activate()
          return
        }

        // Segments without activate: dismiss focus mode
        barFocusActive = false
      }

      // IPC handler for bar focus mode
      IpcHandler {
        target: "bar"

        function enable(): string {
          panel.barFocusActive = true
          panel.barFocusIndex = panel.firstFocusIndex()
          return "Bar focus is now enabled"
        }
        function disable(): string {
          panel.barFocusActive = false
          return "Bar focus is now disabled"
        }
        function toggle(): string {
          return panel.barFocusActive ? disable() : enable()
        }
        function state(): bool { return panel.barFocusActive }
      }

      // Helper function to build props for dynamically loaded bar components.
      // Only pass singleton references to modules that need them to
      // avoid "non-existent property" warnings from Loader.setSource().
      function buildBarComponentProps(moduleId) {
        var props = { "screen": panel.modelData }
        if (popupModules.indexOf(moduleId) !== -1) {
          props.popupManager = PopupManager
          // Inject the manifest id so buttons never restate it
          props.popupId = moduleId
        }
        if (ModuleRegistry.requiresHostWindow(moduleId)) {
          props.hostWindow = panel
        }
        return props
      }

      // Left section
      BarSection {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: StatusbarManager.barMargins.left
        spacing: StatusbarManager.sectionSpacing.left
        items: StatusbarManager.leftItems
        buildProps: panel.buildBarComponentProps
      }

      // Center section
      BarSection {
        id: centerSection
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: StatusbarManager.sectionSpacing.center
        items: StatusbarManager.centerItems
        buildProps: panel.buildBarComponentProps
      }

      // Right section
      BarSection {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: StatusbarManager.barMargins.right
        spacing: StatusbarManager.sectionSpacing.right
        items: StatusbarManager.rightItems
        buildProps: panel.buildBarComponentProps
      }
    }
  }
}
