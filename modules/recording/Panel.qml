import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../.."
import "../../core/components"

Scope {
  id: root

  // PanelWindow is only created when panelOpen is true and destroyed when
  // closed, avoiding the cost of a full-screen Wayland surface at idle.
  Variants {
    model: RecordingManager.panelOpen && ScreenManager.primaryScreen ? [ScreenManager.primaryScreen] : []

    PanelWindow {
      required property var modelData

      id: panel
      screen: modelData

      visible: true

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      color: Theme.overlay
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: "quickshell-screen-recording"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      // -- State ------------------------------------------------------------

      property string activeTab: "screenshots"
      property string viewMode: "grid"
      property string detailPath: ""
      property string searchQuery: ""
      property var filteredFiles: []
      property int filteredCount: 0

      // Grid navigation
      property int selectedIndex: -1
      property int pendingDeleteIndex: -1
      readonly property int columnsPerRow: 5

      // Multi-select (Space to toggle, path-based so it survives refiltering)
      property var selectedPaths: ({})
      property int selectedCount: 0

      onSelectedIndexChanged: pendingDeleteIndex = -1

      function toggleSelection(idx) {
        if (idx < 0 || idx >= filteredCount) return
        var path = filteredFiles[idx]
        var s = selectedPaths
        if (s[path]) delete s[path]
        else s[path] = true
        selectedPaths = s
        selectedCount = Object.keys(s).length
      }

      function clearSelection() {
        selectedPaths = {}
        selectedCount = 0
      }

      function isSelected(idx) {
        if (idx < 0 || idx >= filteredFiles.length) return false
        return !!selectedPaths[filteredFiles[idx]]
      }

      // Detail focus cycling
      property var detailFocusables: []
      property int detailFocusIndex: -1

      // -- File list helpers ------------------------------------------------

      function currentFiles() {
        if (activeTab === "screenshots")
          return RecordingManager.screenshots
        return RecordingManager.screencasts
      }

      function updateFilteredFiles() {
        var files = currentFiles()
        if (!searchQuery) {
          filteredFiles = files
          filteredCount = files.length
        } else {
          var query = searchQuery.toLowerCase()
          var result = files.filter(function(f) {
            var name = f.substring(f.lastIndexOf("/") + 1).toLowerCase()
            return name.indexOf(query) !== -1
          })
          filteredFiles = result
          filteredCount = result.length
        }
        // Clamp selection
        if (selectedIndex >= filteredCount)
          selectedIndex = filteredCount - 1

        // Prune stale multi-selections
        if (selectedCount > 0) {
          var lookup = {}
          for (var j = 0; j < filteredFiles.length; j++)
            lookup[filteredFiles[j]] = true
          var s = selectedPaths
          var changed = false
          for (var p in s) {
            if (!lookup[p]) { delete s[p]; changed = true }
          }
          if (changed) {
            selectedPaths = s
            selectedCount = Object.keys(s).length
          }
        }
      }

      onActiveTabChanged: {
        viewMode = "grid"
        detailPath = ""
        searchQuery = ""
        selectedIndex = -1
        pendingDeleteIndex = -1
        clearSelection()
        updateFilteredFiles()
      }

      onSearchQueryChanged: updateFilteredFiles()

      Connections {
        target: RecordingManager
        function onFilesRefreshed() { panel.updateFilteredFiles() }
        function onFileRenamed(oldPath, newPath) {
          if (panel.detailPath === oldPath) {
            panel.detailPath = newPath
          }
        }
        function onPanelOpenChanged() {
          if (RecordingManager.panelOpen) {
            panel.activeTab = "screenshots"
            panel.viewMode = "grid"
            panel.detailPath = ""
            panel.searchQuery = ""
            panel.selectedIndex = -1
            panel.pendingDeleteIndex = -1
            panel.clearSelection()
            panel.updateFilteredFiles()
          }
        }
      }

      // -- Grid navigation functions ----------------------------------------

      function ensureSelection() {
        if (filteredCount === 0) return false
        if (selectedIndex < 0) { selectedIndex = 0; scrollToCell(0) }
        return true
      }

      function moveLeft() {
        if (!ensureSelection()) return
        if (selectedIndex > 0) selectedIndex--
        scrollToCell(selectedIndex)
      }

      function moveRight() {
        if (!ensureSelection()) return
        if (selectedIndex < filteredCount - 1) selectedIndex++
        scrollToCell(selectedIndex)
      }

      function moveUp() {
        if (!ensureSelection()) return
        var target = selectedIndex - columnsPerRow
        if (target >= 0) selectedIndex = target
        scrollToCell(selectedIndex)
      }

      function moveDown() {
        if (!ensureSelection()) return
        var target = selectedIndex + columnsPerRow
        if (target < filteredCount) selectedIndex = target
        scrollToCell(selectedIndex)
      }

      function pageUp() {
        if (!ensureSelection()) return
        var visibleRows = Math.max(1, Math.floor(gridView.height / gridView.cellHeight))
        var target = selectedIndex - (visibleRows * columnsPerRow)
        selectedIndex = Math.max(0, target)
        scrollToCell(selectedIndex)
      }

      function pageDown() {
        if (!ensureSelection()) return
        var visibleRows = Math.max(1, Math.floor(gridView.height / gridView.cellHeight))
        var target = selectedIndex + (visibleRows * columnsPerRow)
        selectedIndex = Math.min(filteredCount - 1, target)
        scrollToCell(selectedIndex)
      }

      function scrollToCell(idx) {
        if (idx < 0 || !gridView.cellHeight) return
        var row = Math.floor(idx / columnsPerRow)
        var cellTop = row * gridView.cellHeight
        var cellBottom = cellTop + gridView.cellHeight
        var viewTop = gridView.contentY
        var viewBottom = viewTop + gridView.height
        if (cellTop < viewTop) {
          gridView.contentY = cellTop
        } else if (cellBottom > viewBottom) {
          gridView.contentY = cellBottom - gridView.height
        }
      }

      function openSelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredCount) {
          detailPath = filteredFiles[selectedIndex]
          viewMode = "detail"
        }
      }

      function returnToGrid() {
        // Try to restore selection to the file we were viewing
        if (detailPath) {
          var idx = filteredFiles.indexOf(detailPath)
          if (idx >= 0) selectedIndex = idx
        }
        viewMode = "grid"
        detailPath = ""
        detailFocusables = []
        detailFocusIndex = -1
        contentItem.forceActiveFocus()
      }

      // -- Detail focus cycling (Ctrl+N / Ctrl+P) ---------------------------

      function findFocusables(item, result) {
        if (!item || !item.visible) return
        if (item.enabled === false) return
        if (item.showFocusRing !== undefined) {
          result.push(item)
        } else if (item.activeFocusOnTab === true) {
          result.push(item)
        }
        if (item.children) {
          for (var i = 0; i < item.children.length; i++) {
            findFocusables(item.children[i], result)
          }
        }
        if (item.contentItem) {
          findFocusables(item.contentItem, result)
        }
      }

      function refreshDetailFocusables() {
        detailFocusables = []
        findFocusables(detailContainer, detailFocusables)
      }

      function focusItemViaKeyboard(item) {
        if (!item) return
        if (item.keyboardFocus !== undefined) item.keyboardFocus = true
        if (item.showFocusRing !== undefined) item.showFocusRing = true
        if (item.forceActiveFocus) item.forceActiveFocus()
      }

      function focusNextDetail() {
        refreshDetailFocusables()
        if (detailFocusables.length === 0) return
        detailFocusIndex = (detailFocusIndex + 1) % detailFocusables.length
        focusItemViaKeyboard(detailFocusables[detailFocusIndex])
      }

      function focusPreviousDetail() {
        refreshDetailFocusables()
        if (detailFocusables.length === 0) return
        if (detailFocusIndex < 0) detailFocusIndex = detailFocusables.length - 1
        else detailFocusIndex = (detailFocusIndex - 1 + detailFocusables.length) % detailFocusables.length
        focusItemViaKeyboard(detailFocusables[detailFocusIndex])
      }

      // -- Keyboard handler -------------------------------------------------

      contentItem {
        focus: RecordingManager.panelOpen

        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          var inSearch = searchInput.activeFocus

          // Escape / Q: layered dismiss
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            if (inSearch) {
              searchInput.text = ""
              searchInput.focus = false
              panel.contentItem.forceActiveFocus()
            } else if (panel.viewMode === "detail") {
              panel.returnToGrid()
            } else if (panel.selectedCount > 0) {
              panel.clearSelection()
            } else if (panel.pendingDeleteIndex >= 0) {
              panel.pendingDeleteIndex = -1
            } else {
              RecordingManager.closePanel()
            }
            event.accepted = true
            return
          }

          // Ctrl+[: layered dismiss (vim escape)
          if (event.key === Qt.Key_BracketLeft && ctrl) {
            if (inSearch) {
              searchInput.focus = false
              panel.contentItem.forceActiveFocus()
            } else if (panel.viewMode === "detail") {
              panel.returnToGrid()
            } else if (panel.selectedCount > 0) {
              panel.clearSelection()
            } else if (panel.pendingDeleteIndex >= 0) {
              panel.pendingDeleteIndex = -1
            } else {
              RecordingManager.closePanel()
            }
            event.accepted = true
            return
          }

          // Ctrl+F: focus search
          if (event.key === Qt.Key_F && ctrl) {
            searchInput.forceActiveFocus()
            event.accepted = true
            return
          }

          // Don't process navigation keys while typing in search
          if (inSearch) return

          // -- Grid mode keys -----------------------------------------------
          if (panel.viewMode === "grid") {
            // Ctrl+H: switch to previous tab (disabled during selection)
            if (event.key === Qt.Key_H && ctrl) {
              if (panel.selectedCount === 0) {
                panel.activeTab = (panel.activeTab === "screencasts") ? "screenshots" : "screencasts"
              }
              event.accepted = true
            }
            // Ctrl+L: switch to next tab (disabled during selection)
            else if (event.key === Qt.Key_L && ctrl) {
              if (panel.selectedCount === 0) {
                panel.activeTab = (panel.activeTab === "screenshots") ? "screencasts" : "screenshots"
              }
              event.accepted = true
            }
            // Ctrl+J: page down
            else if (event.key === Qt.Key_J && ctrl) {
              panel.pageDown()
              event.accepted = true
            }
            // Ctrl+K: page up
            else if (event.key === Qt.Key_K && ctrl) {
              panel.pageUp()
              event.accepted = true
            }
            // h: move left
            else if (event.key === Qt.Key_H) {
              panel.moveLeft()
              event.accepted = true
            }
            // l: move right
            else if (event.key === Qt.Key_L) {
              panel.moveRight()
              event.accepted = true
            }
            // j: move down one row
            else if (event.key === Qt.Key_J) {
              panel.moveDown()
              event.accepted = true
            }
            // k: move up one row
            else if (event.key === Qt.Key_K) {
              panel.moveUp()
              event.accepted = true
            }
            // Enter: open detail view for focused item
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              panel.openSelected()
              event.accepted = true
            }
            // Space: toggle selection on focused item
            else if (event.key === Qt.Key_Space) {
              if (panel.ensureSelection()) {
                panel.pendingDeleteIndex = -1
                panel.toggleSelection(panel.selectedIndex)
              }
              event.accepted = true
            }
            // d: delete selected files or focused file (two-step when no selection)
            else if (event.key === Qt.Key_D) {
              if (panel.selectedCount > 0) {
                var paths = Object.keys(panel.selectedPaths)
                panel.clearSelection()
                RecordingManager.deleteFiles(paths)
              } else if (panel.pendingDeleteIndex === panel.selectedIndex && panel.selectedIndex >= 0) {
                var singlePath = panel.filteredFiles[panel.selectedIndex]
                panel.pendingDeleteIndex = -1
                RecordingManager.deleteFile(singlePath)
              } else if (panel.selectedIndex >= 0 && panel.selectedIndex < panel.filteredCount) {
                panel.pendingDeleteIndex = panel.selectedIndex
              }
              event.accepted = true
            }
          }

          // -- Detail mode keys ---------------------------------------------
          else if (panel.viewMode === "detail") {
            // Ctrl+N: focus next element
            if (event.key === Qt.Key_N && ctrl) {
              panel.focusNextDetail()
              event.accepted = true
            }
            // Ctrl+P: focus previous element
            else if (event.key === Qt.Key_P && ctrl) {
              panel.focusPreviousDetail()
              event.accepted = true
            }
          }
        }
      }

      // Scrim click to close
      MouseArea {
        anchors.fill: parent
        enabled: RecordingManager.panelOpen
        onClicked: {
          if (panel.viewMode === "detail") {
            panel.returnToGrid()
          } else {
            RecordingManager.closePanel()
          }
        }
      }

      // -- Panel container --------------------------------------------------

      Rectangle {
        id: panelRect
        anchors.centerIn: parent
        width: parent.width * 0.6
        height: parent.height * 0.7
        color: Theme.bgBase
        radius: 8
        border.width: 1
        border.color: Theme.bgBorder

        // Absorb clicks on the panel itself
        MouseArea {
          anchors.fill: parent
          onClicked: function(event) { event.accepted = true }
        }

        Column {
          id: panelColumn
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // -- Tab bar ------------------------------------------------------

          Row {
            id: tabBar
            spacing: 0
            width: parent.width

            Repeater {
              model: [
                { id: "screenshots", label: "Screenshots" },
                { id: "screencasts", label: "Screencasts" }
              ]

              Rectangle {
                required property var modelData
                required property int index

                width: tabBar.width / 2
                height: 40
                color: panel.activeTab === modelData.id ? Theme.bgCard : "transparent"
                radius: 6

                Text {
                  anchors.centerIn: parent
                  text: modelData.label
                  color: panel.activeTab === modelData.id ? Theme.textPrimary : Theme.textSecondary
                  font.pixelSize: 15
                  font.bold: panel.activeTab === modelData.id
                }

                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width * 0.6
                  height: 3
                  radius: 1.5
                  color: Theme.accent
                  visible: panel.activeTab === modelData.id
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panel.activeTab = modelData.id
                }
              }
            }
          }

          // -- Search input -------------------------------------------------

          Rectangle {
            id: searchBar
            width: parent.width
            height: 36
            radius: 6
            color: Theme.bgCardHover
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Theme.focusRing : Theme.bgBorder
            visible: panel.viewMode === "grid"

            Text {
              id: searchIcon
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍉"
              font.family: "Symbols Nerd Font"
              font.pixelSize: 14
              color: Theme.textMuted
            }

            TextInput {
              id: searchInput
              anchors.left: searchIcon.right
              anchors.leftMargin: 8
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              color: Theme.textPrimary
              font.pixelSize: 14
              verticalAlignment: TextInput.AlignVCenter
              activeFocusOnTab: true
              selectByMouse: true
              clip: true

              property bool showFocusRing: false

              Text {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                text: "Search files..."
                color: Theme.textMuted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                visible: !searchInput.text && !searchInput.activeFocus
              }

              onTextChanged: {
                panel.searchQuery = text
                panel.selectedIndex = -1
              }

              Keys.onEscapePressed: {
                text = ""
                focus = false
                panel.contentItem.forceActiveFocus()
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onPressed: function(mouse) {
                searchInput.forceActiveFocus()
                mouse.accepted = false
              }
            }
          }

          // -- Content area -------------------------------------------------

          Item {
            width: parent.width
            height: parent.height - tabBar.height - (searchBar.visible ? searchBar.height + panelColumn.spacing : 0) - panelColumn.spacing

            // -- Grid view --------------------------------------------------

            Item {
              id: gridContainer
              anchors.fill: parent
              visible: panel.viewMode === "grid"

              GridView {
                id: gridView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: deleteAllRow.top
                anchors.bottomMargin: 8
                clip: true
                cellWidth: width / 5
                cellHeight: cellWidth * 0.75
                model: panel.filteredCount

                delegate: Item {
                  required property int index

                  width: gridView.cellWidth
                  height: gridView.cellHeight

                  // Focus / selection ring
                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 2
                    height: parent.height - 2
                    radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: {
                      if (index === panel.selectedIndex && index === panel.pendingDeleteIndex)
                        return Theme.danger
                      if (index === panel.selectedIndex)
                        return Theme.focusRing
                      if (panel.isSelected(index))
                        return Theme.accent
                      return Theme.focusRing
                    }
                    visible: index === panel.selectedIndex || panel.isSelected(index)
                    z: 1
                  }

                  Rectangle {
                    id: cellRect
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 6
                    color: {
                      if (index === panel.pendingDeleteIndex)
                        return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
                      if (index === panel.selectedIndex)
                        return Theme.bgCardHover
                      return Theme.bgCard
                    }
                    border.width: index === panel.selectedIndex ? 2 : 1
                    border.color: {
                      if (index === panel.pendingDeleteIndex)
                        return Theme.danger
                      if (index === panel.selectedIndex)
                        return Theme.focusRing
                      return Theme.bgBorder
                    }
                    clip: true

                    property string filePath: index < panel.filteredFiles.length ? panel.filteredFiles[index] : ""

                    // Screenshot thumbnail
                    Image {
                      id: screenshotThumb
                      anchors.fill: parent
                      anchors.margins: 1
                      fillMode: Image.PreserveAspectCrop
                      source: cellRect.filePath && panel.activeTab === "screenshots" ? "file://" + cellRect.filePath : ""
                      sourceSize.width: gridView.cellWidth * 2
                      sourceSize.height: gridView.cellHeight * 2
                      asynchronous: true
                      cache: false
                      visible: panel.activeTab === "screenshots" && status === Image.Ready
                    }

                    // Screencast thumbnail (lazy-loaded)
                    Image {
                      id: screencastThumb
                      anchors.fill: parent
                      anchors.margins: 1
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      cache: false
                      visible: panel.activeTab === "screencasts" && status === Image.Ready

                      property string videoPath: cellRect.filePath
                      property string thumbPath: videoPath ? RecordingManager.getThumbnailPath(videoPath) : ""

                      source: thumbPath ? "file://" + thumbPath : ""

                      onStatusChanged: {
                        if (panel.activeTab === "screencasts" && status === Image.Error && videoPath) {
                          RecordingManager.requestThumbnail(videoPath)
                        }
                      }

                      Component.onCompleted: {
                        if (panel.activeTab === "screencasts" && videoPath) {
                          source = Qt.binding(function() { return thumbPath ? "file://" + thumbPath : "" })
                        }
                      }

                      Connections {
                        target: RecordingManager
                        function onThumbnailReady(vPath, tPath) {
                          if (vPath === screencastThumb.videoPath) {
                            screencastThumb.source = ""
                            screencastThumb.source = "file://" + tPath
                          }
                        }
                      }
                    }

                    // Video play icon overlay
                    Text {
                      anchors.centerIn: parent
                      text: "\uf04b"
                      font.family: "Symbols Nerd Font"
                      font.pixelSize: 24
                      color: Theme.textPrimary
                      opacity: 0.8
                      visible: panel.activeTab === "screencasts"

                      Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 18
                        color: Theme.bgBase
                        opacity: 0.6
                        z: -1
                      }
                    }

                    // Loading placeholder
                    Text {
                      anchors.centerIn: parent
                      text: panel.activeTab === "screenshots" ? "\uf03e" : "\uf03d"
                      font.family: "Symbols Nerd Font"
                      font.pixelSize: 28
                      color: Theme.textMuted
                      visible: {
                        if (panel.activeTab === "screenshots")
                          return screenshotThumb.status !== Image.Ready
                        return screencastThumb.status !== Image.Ready
                      }
                    }

                    // Filename label
                    Rectangle {
                      anchors.bottom: parent.bottom
                      anchors.left: parent.left
                      anchors.right: parent.right
                      height: 22
                      color: Theme.bgBase
                      opacity: 0.85

                      Text {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        text: {
                          if (!cellRect.filePath) return ""
                          return cellRect.filePath.substring(cellRect.filePath.lastIndexOf("/") + 1)
                        }
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                      }
                    }

                    MouseArea {
                      id: thumbMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onContainsMouseChanged: {
                        if (containsMouse) panel.selectedIndex = index
                      }
                      onClicked: {
                        if (cellRect.filePath) {
                          panel.selectedIndex = index
                          panel.detailPath = cellRect.filePath
                          panel.viewMode = "detail"
                        }
                      }
                    }
                  }
                }

                // Empty state
                Text {
                  anchors.centerIn: parent
                  text: panel.searchQuery
                    ? "No matching files"
                    : (panel.activeTab === "screenshots" ? "No screenshots found" : "No screencasts found")
                  color: Theme.textMuted
                  font.pixelSize: 15
                  visible: panel.filteredCount === 0
                }
              }

              // Delete all button
              Row {
                id: deleteAllRow
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                spacing: 8
                visible: panel.filteredCount > 0

                property bool confirmDelete: false

                Text {
                  text: "Are you sure?"
                  color: Theme.danger
                  font.pixelSize: 13
                  anchors.verticalCenter: parent.verticalCenter
                  visible: deleteAllRow.confirmDelete
                }

                FocusButton {
                  text: deleteAllRow.confirmDelete ? "Yes, delete all" : ("Delete all " + panel.activeTab)
                  backgroundColor: Theme.danger
                  textColor: Theme.bgBase
                  hoverColor: Qt.darker(Theme.danger, 1.2)
                  onClicked: {
                    if (deleteAllRow.confirmDelete) {
                      RecordingManager.deleteAll(panel.activeTab)
                      deleteAllRow.confirmDelete = false
                    } else {
                      deleteAllRow.confirmDelete = true
                    }
                  }
                }

                FocusButton {
                  text: "Cancel"
                  visible: deleteAllRow.confirmDelete
                  onClicked: deleteAllRow.confirmDelete = false
                }
              }
            }

            // -- Detail view ------------------------------------------------

            Item {
              id: detailContainer
              anchors.fill: parent
              visible: panel.viewMode === "detail"

              property string fileName: {
                if (!panel.detailPath) return ""
                return panel.detailPath.substring(panel.detailPath.lastIndexOf("/") + 1)
              }

              property string baseName: {
                if (!fileName) return ""
                var dotIdx = fileName.lastIndexOf(".")
                if (dotIdx === -1) return fileName
                return fileName.substring(0, dotIdx)
              }

              property string extension: {
                if (!fileName) return ""
                var dotIdx = fileName.lastIndexOf(".")
                if (dotIdx === -1) return ""
                return fileName.substring(dotIdx)
              }

              property bool isVideo: panel.activeTab === "screencasts"
              property bool confirmDelete: false

              Connections {
                target: panel
                function onViewModeChanged() {
                  detailContainer.confirmDelete = false
                  if (panel.viewMode === "detail") {
                    panel.detailFocusIndex = -1
                  }
                }
              }

              Column {
                anchors.fill: parent
                spacing: 12

                // Top bar with back button
                Row {
                  spacing: 12
                  width: parent.width

                  FocusButton {
                    text: "Back to overview"
                    width: 160
                    onClicked: panel.returnToGrid()
                  }

                  Item { width: 1; height: 1 }
                }

                // Preview area
                Item {
                  width: parent.width
                  height: Math.max(100, parent.height - 182)
                  clip: true

                  // Screenshot preview with open-in-previewer overlay
                  Item {
                    anchors.fill: parent
                    visible: !detailContainer.isVideo && panel.detailPath !== ""

                    Image {
                      id: detailImage
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectFit
                      source: parent.visible ? "file://" + panel.detailPath : ""
                      asynchronous: true
                      cache: false
                    }

                    // Open in previewer overlay
                    Rectangle {
                      anchors.centerIn: parent
                      width: 72
                      height: 72
                      radius: 36
                      color: Theme.bgBase
                      opacity: detailImageMouse.containsMouse ? 0.95 : 0
                      visible: opacity > 0

                      Behavior on opacity {
                        NumberAnimation { duration: 150 }
                      }

                      Text {
                        anchors.centerIn: parent
                        text: "󰍉"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 28
                        color: Theme.textPrimary
                      }
                    }

                    MouseArea {
                      id: detailImageMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (panel.detailPath)
                          RecordingManager.openFile(panel.detailPath)
                      }
                    }
                  }

                  // Screencast preview: thumbnail with play button to open in default player
                  Item {
                    anchors.fill: parent
                    visible: detailContainer.isVideo && panel.detailPath !== ""

                    Image {
                      id: detailVideoThumb
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: false

                      property string thumbPath: panel.detailPath ? RecordingManager.getThumbnailPath(panel.detailPath) : ""
                      source: thumbPath ? "file://" + thumbPath : ""

                      onStatusChanged: {
                        if (status === Image.Error && panel.detailPath) {
                          RecordingManager.requestThumbnail(panel.detailPath)
                        }
                      }

                      Connections {
                        target: RecordingManager
                        function onThumbnailReady(vPath, tPath) {
                          if (vPath === panel.detailPath) {
                            detailVideoThumb.source = ""
                            detailVideoThumb.source = "file://" + tPath
                          }
                        }
                      }
                    }

                    // Play button overlay
                    Rectangle {
                      anchors.centerIn: parent
                      width: 72
                      height: 72
                      radius: 36
                      color: Theme.bgBase
                      opacity: detailPlayMouse.containsMouse ? 0.95 : 0.75

                      Behavior on opacity {
                        NumberAnimation { duration: 150 }
                      }

                      Text {
                        anchors.centerIn: parent
                        text: "\uf04b"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 28
                        color: Theme.textPrimary
                      }
                    }

                    MouseArea {
                      id: detailPlayMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (panel.detailPath)
                          RecordingManager.openFile(panel.detailPath)
                      }
                    }
                  }

                  // Loading state
                  Text {
                    anchors.centerIn: parent
                    text: "Loading..."
                    color: Theme.textMuted
                    font.pixelSize: 15
                    visible: {
                      if (detailContainer.isVideo) return false
                      return detailImage.status === Image.Loading
                    }
                  }
                }

                // Rename row
                Row {
                  width: parent.width
                  spacing: 8

                  Text {
                    text: "Name:"
                    color: Theme.textSecondary
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  FocusTextInput {
                    id: renameInput
                    width: parent.width - 200
                    text: detailContainer.baseName
                    onEditingFinished: function(value) {
                      if (value && value !== detailContainer.baseName) {
                        RecordingManager.renameFile(panel.detailPath, value)
                      }
                      panel.contentItem.forceActiveFocus()
                    }
                  }

                  Text {
                    text: detailContainer.extension
                    color: Theme.textMuted
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Action buttons row
                Row {
                  spacing: 8

                  FocusButton {
                    id: openBtn
                    text: "Open"
                    width: 80
                    onClicked: RecordingManager.openFile(panel.detailPath)
                  }

                  FocusButton {
                    id: copyBtn
                    text: "Copy path"
                    width: 120
                    onClicked: RecordingManager.copyPath(panel.detailPath)
                  }

                  FocusButton {
                    id: deleteBtn
                    text: "Delete"
                    width: 100
                    backgroundColor: Theme.danger
                    textColor: Theme.bgBase
                    hoverColor: Qt.darker(Theme.danger, 1.2)
                    visible: !detailContainer.confirmDelete
                    onClicked: detailContainer.confirmDelete = true
                  }

                  FocusButton {
                    id: confirmDeleteBtn
                    text: "Confirm delete"
                    width: 140
                    backgroundColor: Theme.danger
                    textColor: Theme.bgBase
                    hoverColor: Qt.darker(Theme.danger, 1.2)
                    visible: detailContainer.confirmDelete
                    onClicked: {
                      RecordingManager.deleteFile(panel.detailPath)
                      panel.viewMode = "grid"
                      panel.detailPath = ""
                    }
                  }

                  FocusButton {
                    id: cancelDeleteBtn
                    text: "Cancel"
                    width: 100
                    visible: detailContainer.confirmDelete
                    onClicked: detailContainer.confirmDelete = false
                  }
                }

                // File path info
                Text {
                  text: panel.detailPath
                  color: Theme.textMuted
                  font.pixelSize: 11
                  elide: Text.ElideLeft
                  width: parent.width
                }
              }
            }
          }
        }
      }
    }
  }
}
