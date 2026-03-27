import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

Scope {
  id: root

  Variants {
    model: WallpaperManager.panelOpen && ScreenManager.primaryScreen
             ? [ScreenManager.primaryScreen] : []

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

      WlrLayershell.namespace: "quickshell-wallpaper"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      // -- State ------------------------------------------------------------

      property string activeTab: "local"
      property string searchQuery: ""
      property int selectedIndex: -1
      property int pendingDeleteIndex: -1
      readonly property int columnsPerRow: 4

      // Preview state
      property bool previewOpen: false
      property var previewItem: null
      property string previewSource: ""
      property bool previewIsLocal: false

      // Sorting for browse tab
      property string browseSorting: "toplist"
      readonly property var sortOptions: [
        { value: "toplist", label: "Top" },
        { value: "date_added", label: "Latest" },
        { value: "random", label: "Random" },
        { value: "views", label: "Views" },
        { value: "favorites", label: "Favorites" },
        { value: "hot", label: "Hot" }
      ]

      onActiveTabChanged: {
        searchQuery = ""
        selectedIndex = -1
        pendingDeleteIndex = -1
        previewOpen = false
        previewItem = null
        previewSource = ""

        if (activeTab === "local") {
          WallpaperManager.refreshLocalFiles()
        }

        contentItem.forceActiveFocus()
      }

      // -- Computed display lists -------------------------------------------

      property var displayFiles: []
      property int displayCount: 0

      function updateDisplayFiles() {
        if (activeTab === "local") {
          if (!searchQuery) {
            displayFiles = WallpaperManager.localFiles
            displayCount = WallpaperManager.localFileCount
          } else {
            var query = searchQuery.toLowerCase()
            var result = WallpaperManager.localFiles.filter(function(f) {
              var name = f.substring(f.lastIndexOf("/") + 1).toLowerCase()
              return name.indexOf(query) !== -1
            })
            displayFiles = result
            displayCount = result.length
          }
        } else {
          // Browse tab: results come from WallpaperManager.searchResults
          displayFiles = []
          displayCount = WallpaperManager.searchResultCount
        }

        if (selectedIndex >= displayCount)
          selectedIndex = displayCount - 1
      }

      onSearchQueryChanged: {
        if (activeTab === "local") updateDisplayFiles()
      }

      Connections {
        target: WallpaperManager
        function onLocalFilesRefreshed() { panel.updateDisplayFiles() }
        function onSearchCompleted() {
          panel.updateDisplayFiles()
          panel.contentItem.forceActiveFocus()
        }
        function onPanelOpenChanged() {
          if (WallpaperManager.panelOpen) {
            panel.activeTab = "local"
            panel.searchQuery = ""
            panel.selectedIndex = -1
            panel.pendingDeleteIndex = -1
            panel.previewOpen = false
            panel.previewItem = null
            panel.previewSource = ""
            panel.updateDisplayFiles()
          }
        }
      }

      // -- Grid navigation --------------------------------------------------

      function ensureSelection() {
        var count = activeTab === "local" ? displayCount : WallpaperManager.searchResultCount
        if (count === 0) return false
        if (selectedIndex < 0) { selectedIndex = 0; scrollToCell(0) }
        return true
      }

      function moveLeft() {
        if (!ensureSelection()) return
        if (selectedIndex > 0) selectedIndex--
        scrollToCell(selectedIndex)
      }

      function moveRight() {
        var count = activeTab === "local" ? displayCount : WallpaperManager.searchResultCount
        if (!ensureSelection()) return
        if (selectedIndex < count - 1) selectedIndex++
        scrollToCell(selectedIndex)
      }

      function moveUp() {
        if (!ensureSelection()) return
        var target = selectedIndex - columnsPerRow
        if (target >= 0) selectedIndex = target
        scrollToCell(selectedIndex)
      }

      function moveDown() {
        var count = activeTab === "local" ? displayCount : WallpaperManager.searchResultCount
        if (!ensureSelection()) return
        var target = selectedIndex + columnsPerRow
        if (target < count) selectedIndex = target
        scrollToCell(selectedIndex)
      }

      function getActiveGridView() {
        return activeTab === "local" ? gridView : browseGridView
      }

      function pageUp() {
        if (!ensureSelection()) return
        var gv = getActiveGridView()
        if (!gv || !gv.cellHeight) return
        var visibleRows = Math.max(1, Math.floor(gv.height / gv.cellHeight))
        var target = selectedIndex - (visibleRows * columnsPerRow)
        selectedIndex = Math.max(0, target)
        scrollToCell(selectedIndex)
      }

      function pageDown() {
        var count = activeTab === "local" ? displayCount : WallpaperManager.searchResultCount
        if (!ensureSelection()) return
        var gv = getActiveGridView()
        if (!gv || !gv.cellHeight) return
        var visibleRows = Math.max(1, Math.floor(gv.height / gv.cellHeight))
        var target = selectedIndex + (visibleRows * columnsPerRow)
        selectedIndex = Math.min(count - 1, target)
        scrollToCell(selectedIndex)
      }

      function scrollToCell(idx) {
        var gv = getActiveGridView()
        if (!gv || idx < 0 || !gv.cellHeight) return
        var row = Math.floor(idx / columnsPerRow)
        var cellTop = row * gv.cellHeight
        var cellBottom = cellTop + gv.cellHeight
        var viewTop = gv.contentY
        var viewBottom = viewTop + gv.height
        if (cellTop < viewTop) {
          gv.contentY = cellTop
        } else if (cellBottom > viewBottom) {
          gv.contentY = cellBottom - gv.height
        }
      }

      function openPreview(idx) {
        if (activeTab === "local") {
          if (idx < 0 || idx >= displayCount) return
          previewSource = displayFiles[idx]
          previewIsLocal = true
          previewItem = null
        } else {
          if (idx < 0 || idx >= WallpaperManager.searchResultCount) return
          var item = WallpaperManager.searchResults[idx]
          previewSource = item.thumbOriginal
          previewIsLocal = false
          previewItem = item
        }
        previewOpen = true
      }

      function closePreview() {
        previewOpen = false
        previewItem = null
        previewSource = ""
        contentItem.forceActiveFocus()
      }

      // -- Keyboard handler -------------------------------------------------

      contentItem {
        focus: WallpaperManager.panelOpen

        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          var inSearch = searchInput.activeFocus

          // Escape / Q: layered dismiss
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            if (inSearch) {
              searchInput.text = ""
              searchInput.focus = false
              panel.contentItem.forceActiveFocus()
            } else if (panel.previewOpen) {
              panel.closePreview()
            } else if (panel.pendingDeleteIndex >= 0) {
              panel.pendingDeleteIndex = -1
            } else {
              WallpaperManager.closePanel()
            }
            event.accepted = true
            return
          }

          // Ctrl+[: vim escape
          if (event.key === Qt.Key_BracketLeft && ctrl) {
            if (inSearch) {
              searchInput.focus = false
              panel.contentItem.forceActiveFocus()
            } else if (panel.previewOpen) {
              panel.closePreview()
            } else if (panel.pendingDeleteIndex >= 0) {
              panel.pendingDeleteIndex = -1
            } else {
              WallpaperManager.closePanel()
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

          if (inSearch) return

          // -- Preview mode keys --------------------------------------------
          if (panel.previewOpen) {
            // Enter/Space: apply wallpaper
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
              if (panel.previewIsLocal) {
                WallpaperManager.applyWallpaper(panel.previewSource)
                panel.closePreview()
              } else if (panel.previewItem) {
                WallpaperManager.downloadAndApply(panel.previewItem.fullPath, panel.previewItem.id)
                panel.closePreview()
              }
              event.accepted = true
            }
            return
          }

          // -- Grid mode keys -----------------------------------------------

          // Ctrl+H: switch to previous tab
          if (event.key === Qt.Key_H && ctrl) {
            panel.activeTab = (panel.activeTab === "browse") ? "local" : "browse"
            event.accepted = true
          }
          // Ctrl+L: switch to next tab
          else if (event.key === Qt.Key_L && ctrl) {
            panel.activeTab = (panel.activeTab === "local") ? "browse" : "local"
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
          // Enter: preview
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (panel.ensureSelection()) panel.openPreview(panel.selectedIndex)
            event.accepted = true
          }
          // Space: quick-apply (local) or download+apply (browse)
          else if (event.key === Qt.Key_Space) {
            if (panel.ensureSelection()) {
              if (panel.activeTab === "local" && panel.selectedIndex < panel.displayCount) {
                WallpaperManager.applyWallpaper(panel.displayFiles[panel.selectedIndex])
              } else if (panel.activeTab === "browse" && panel.selectedIndex < WallpaperManager.searchResultCount) {
                var item = WallpaperManager.searchResults[panel.selectedIndex]
                WallpaperManager.downloadAndApply(item.fullPath, item.id)
              }
            }
            event.accepted = true
          }
          // d: delete local file (two-step)
          else if (event.key === Qt.Key_D && panel.activeTab === "local") {
            if (panel.pendingDeleteIndex === panel.selectedIndex && panel.selectedIndex >= 0) {
              var path = panel.displayFiles[panel.selectedIndex]
              panel.pendingDeleteIndex = -1
              WallpaperManager.deleteFile(path)
            } else if (panel.selectedIndex >= 0 && panel.selectedIndex < panel.displayCount) {
              panel.pendingDeleteIndex = panel.selectedIndex
            }
            event.accepted = true
          }
          // n: next page (browse tab)
          else if (event.key === Qt.Key_N && !ctrl && panel.activeTab === "browse") {
            WallpaperManager.searchNextPage()
            event.accepted = true
          }
          // p: previous page (browse tab)
          else if (event.key === Qt.Key_P && !ctrl && panel.activeTab === "browse") {
            WallpaperManager.searchPreviousPage()
            event.accepted = true
          }
        }
      }

      // Scrim click to close
      MouseArea {
        anchors.fill: parent
        enabled: WallpaperManager.panelOpen
        onClicked: {
          if (panel.previewOpen) panel.closePreview()
          else WallpaperManager.closePanel()
        }
      }

      // -- Panel container --------------------------------------------------

      Rectangle {
        id: panelRect
        anchors.centerIn: parent
        width: parent.width * 0.65
        height: parent.height * 0.75
        color: Theme.bgBase
        radius: 8
        border.width: 1
        border.color: Theme.bgBorder

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
                { id: "local", label: "Local" },
                { id: "browse", label: "Wallhaven" }
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

          // -- Search / filter bar ------------------------------------------

          Row {
            id: searchFilterRow
            width: parent.width
            spacing: 8
            z: 1

            // Search input
            Rectangle {
              id: searchBar
              width: panel.activeTab === "browse" ? parent.width - sortDropdown.width - 8 : parent.width
              height: 36
              radius: 6
              color: Theme.bgCardHover
              border.width: searchInput.activeFocus ? 2 : 1
              border.color: searchInput.activeFocus ? Theme.focusRing : Theme.bgBorder

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
                  text: panel.activeTab === "local" ? "Search local files..." : "Search wallhaven..."
                  color: Theme.textMuted
                  font.pixelSize: 14
                  verticalAlignment: Text.AlignVCenter
                  visible: !searchInput.text && !searchInput.activeFocus
                }

                onTextChanged: {
                  if (panel.activeTab === "local") {
                    panel.searchQuery = text
                    panel.selectedIndex = -1
                  }
                }

                // Submit search on Enter for browse tab
                Keys.onReturnPressed: {
                  if (panel.activeTab === "browse") {
                    WallpaperManager.search(text, panel.browseSorting, 1)
                    focus = false
                    panel.contentItem.forceActiveFocus()
                  }
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

            // Sort dropdown (browse tab only)
            Rectangle {
              id: sortDropdown
              width: 120
              height: 36
              radius: 6
              color: sortMouse.containsMouse ? Theme.bgCardHover : Theme.bgCard
              border.width: 1
              border.color: Theme.bgBorder
              visible: panel.activeTab === "browse"

              Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                  text: {
                    for (var i = 0; i < panel.sortOptions.length; i++) {
                      if (panel.sortOptions[i].value === panel.browseSorting)
                        return panel.sortOptions[i].label
                    }
                    return "Top"
                  }
                  color: Theme.textPrimary
                  font.pixelSize: 14
                }

                Text {
                  text: sortMenu.visible ? "▲" : "▼"
                  color: Theme.textMuted
                  font.pixelSize: 10
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: sortMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sortMenu.visible = !sortMenu.visible
              }

              // Sort options menu
              Rectangle {
                id: sortMenu
                visible: false
                anchors.top: parent.bottom
                anchors.topMargin: 4
                anchors.right: parent.right
                width: parent.width
                height: sortMenuColumn.height + 8
                radius: 6
                color: Theme.bgCard
                border.width: 1
                border.color: Theme.bgBorder
                z: 100

                Column {
                  id: sortMenuColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: 4

                  Repeater {
                    model: panel.sortOptions

                    Rectangle {
                      required property var modelData
                      required property int index

                      width: sortMenuColumn.width
                      height: 32
                      radius: 4
                      color: sortItemMouse.containsMouse ? Theme.bgCardHover : "transparent"

                      Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: panel.browseSorting === modelData.value ? Theme.accent : Theme.textPrimary
                        font.pixelSize: 14
                        font.bold: panel.browseSorting === modelData.value
                      }

                      MouseArea {
                        id: sortItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          panel.browseSorting = modelData.value
                          sortMenu.visible = false
                          WallpaperManager.search(searchInput.text, modelData.value, 1)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // -- Content area -------------------------------------------------

          Item {
            width: parent.width
            height: parent.height - tabBar.height - searchFilterRow.height - panelColumn.spacing * 2

            // -- Grid view (local tab) --------------------------------------

            Item {
              id: localGridContainer
              anchors.fill: parent
              visible: panel.activeTab === "local" && !panel.previewOpen

              GridView {
                id: gridView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: localHelpRow.top
                anchors.bottomMargin: 8
                clip: true
                cellWidth: width / panel.columnsPerRow
                cellHeight: cellWidth * 0.6
                model: panel.displayCount

                delegate: Item {
                  required property int index

                  width: gridView.cellWidth
                  height: gridView.cellHeight

                  // Focus ring
                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 2
                    height: parent.height - 2
                    radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: {
                      if (index === panel.pendingDeleteIndex)
                        return Theme.danger
                      if (index === panel.selectedIndex)
                        return Theme.focusRing
                      return Theme.focusRing
                    }
                    visible: index === panel.selectedIndex
                    z: 1
                  }

                  Rectangle {
                    id: localCell
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

                    property string filePath: index < panel.displayFiles.length ? panel.displayFiles[index] : ""

                    // Active wallpaper indicator
                    Rectangle {
                      anchors.top: parent.top
                      anchors.right: parent.right
                      anchors.topMargin: 6
                      anchors.rightMargin: 6
                      width: 20
                      height: 20
                      radius: 10
                      color: Theme.accent
                      visible: localCell.filePath === WallpaperManager.currentWallpaper
                      z: 2

                      Text {
                        anchors.centerIn: parent
                        text: "󰄬"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: Theme.bgDeep
                      }
                    }

                    Image {
                      anchors.fill: parent
                      anchors.margins: 1
                      fillMode: Image.PreserveAspectCrop
                      source: localCell.filePath ? "file://" + localCell.filePath : ""
                      sourceSize.width: gridView.cellWidth * 2
                      sourceSize.height: gridView.cellHeight * 2
                      asynchronous: true
                      cache: false
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
                          if (!localCell.filePath) return ""
                          return localCell.filePath.substring(localCell.filePath.lastIndexOf("/") + 1)
                        }
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onContainsMouseChanged: {
                        if (containsMouse) panel.selectedIndex = index
                      }
                      onClicked: {
                        panel.selectedIndex = index
                        panel.openPreview(index)
                      }
                    }
                  }
                }

                // Empty state
                Text {
                  anchors.centerIn: parent
                  text: panel.searchQuery ? "No matching files" : "No wallpapers found"
                  color: Theme.textMuted
                  font.pixelSize: 15
                  visible: panel.displayCount === 0
                }
              }

              // Help row
              Row {
                id: localHelpRow
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                spacing: 16

                Row {
                  spacing: 4
                  KeyboardTag { text: "Space"; anchors.verticalCenter: parent.verticalCenter }
                  AnnotationText { text: "Apply"; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                  spacing: 4
                  KeyboardTag { text: "Enter"; anchors.verticalCenter: parent.verticalCenter }
                  AnnotationText { text: "Preview"; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                  spacing: 4
                  KeyboardTag { text: "d d"; anchors.verticalCenter: parent.verticalCenter }
                  AnnotationText { text: "Delete"; anchors.verticalCenter: parent.verticalCenter }
                }
              }
            }

            // -- Grid view (browse tab) -------------------------------------

            Item {
              id: browseGridContainer
              anchors.fill: parent
              visible: panel.activeTab === "browse" && !panel.previewOpen

              GridView {
                id: browseGridView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: browseFooter.top
                anchors.bottomMargin: 8
                clip: true
                cellWidth: width / panel.columnsPerRow
                cellHeight: cellWidth * 0.6
                model: WallpaperManager.searchResultCount

                delegate: Item {
                  required property int index

                  width: browseGridView.cellWidth
                  height: browseGridView.cellHeight

                  // Focus ring
                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 2
                    height: parent.height - 2
                    radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.focusRing
                    visible: index === panel.selectedIndex
                    z: 1
                  }

                  Rectangle {
                    id: browseCell
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 6
                    color: index === panel.selectedIndex ? Theme.bgCardHover : Theme.bgCard
                    border.width: index === panel.selectedIndex ? 2 : 1
                    border.color: index === panel.selectedIndex ? Theme.focusRing : Theme.bgBorder

                    property var itemData: index < WallpaperManager.searchResults.length
                                             ? WallpaperManager.searchResults[index] : null

                    Image {
                      anchors.fill: parent
                      anchors.margins: 1
                      fillMode: Image.PreserveAspectCrop
                      source: browseCell.itemData ? browseCell.itemData.thumbLarge : ""
                      sourceSize.width: browseGridView.cellWidth * 2
                      sourceSize.height: browseGridView.cellHeight * 2
                      asynchronous: true
                      cache: false
                    }

                    // Loading spinner placeholder
                    Text {
                      anchors.centerIn: parent
                      text: "󰋩"
                      font.family: "Symbols Nerd Font"
                      font.pixelSize: 28
                      color: Theme.textMuted
                      visible: !browseCell.itemData
                    }

                    // Resolution label
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
                        text: browseCell.itemData ? browseCell.itemData.resolution : ""
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                      }
                    }

                    // Download indicator
                    Rectangle {
                      anchors.top: parent.top
                      anchors.right: parent.right
                      anchors.topMargin: 6
                      anchors.rightMargin: 6
                      width: 20
                      height: 20
                      radius: 10
                      color: Theme.accent
                      visible: browseCell.itemData && WallpaperManager.downloadingId === browseCell.itemData.id
                      z: 2

                      Text {
                        anchors.centerIn: parent
                        text: "󰇚"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: Theme.bgDeep
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onContainsMouseChanged: {
                        if (containsMouse) panel.selectedIndex = index
                      }
                      onClicked: {
                        panel.selectedIndex = index
                        panel.openPreview(index)
                      }
                    }
                  }
                }

                // Empty state
                Column {
                  anchors.centerIn: parent
                  spacing: 8
                  visible: WallpaperManager.searchResultCount === 0 && !WallpaperManager.searching

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Search wallhaven.cc for wallpapers"
                    color: Theme.textMuted
                    font.pixelSize: 15
                  }

                  HelpText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Type a search query and press Enter, or browse by category"
                  }
                }

                // Loading state
                Text {
                  anchors.centerIn: parent
                  text: "Searching..."
                  color: Theme.textMuted
                  font.pixelSize: 15
                  visible: WallpaperManager.searching
                }
              }

              // Footer: pagination + help
              Row {
                id: browseFooter
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 16

                // Pagination
                Row {
                  id: paginationRow
                  spacing: 8
                  visible: WallpaperManager.lastPage > 1

                  FocusButton {
                    text: "󰅁 Prev"
                    width: 80
                    height: 28
                    fontSize: 12
                    backgroundColor: Theme.bgCard
                    hoverColor: Theme.bgCardHover
                    enabled: WallpaperManager.currentPage > 1
                    onClicked: WallpaperManager.searchPreviousPage()
                  }

                  Text {
                    text: WallpaperManager.currentPage + " / " + WallpaperManager.lastPage
                    color: Theme.textSecondary
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  FocusButton {
                    text: "Next 󰅂"
                    width: 80
                    height: 28
                    fontSize: 12
                    backgroundColor: Theme.bgCard
                    hoverColor: Theme.bgCardHover
                    enabled: WallpaperManager.currentPage < WallpaperManager.lastPage
                    onClicked: WallpaperManager.searchNextPage()
                  }
                }

                Item { height: 1; width: Math.max(0, parent.width - paginationRow.width - browseHelpRow.width - parent.spacing * 2) }

                // Help
                Row {
                  id: browseHelpRow
                  spacing: 16
                  anchors.verticalCenter: parent.verticalCenter

                  Row {
                    spacing: 4
                    KeyboardTag { text: "Space"; anchors.verticalCenter: parent.verticalCenter }
                    AnnotationText { text: "Download & apply"; anchors.verticalCenter: parent.verticalCenter }
                  }

                  Row {
                    spacing: 4
                    KeyboardTag { text: "n"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "/"; color: Theme.textMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    KeyboardTag { text: "p"; anchors.verticalCenter: parent.verticalCenter }
                    AnnotationText { text: "Page"; anchors.verticalCenter: parent.verticalCenter }
                  }
                }
              }

              // Quick-browse buttons (shown when no search results yet)
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: browseFooter.top
                anchors.bottomMargin: 16
                spacing: 8
                visible: WallpaperManager.searchResultCount === 0 && !WallpaperManager.searching

                FocusButton {
                  text: "Top"
                  backgroundColor: Theme.bgCard
                  hoverColor: Theme.bgCardHover
                  onClicked: {
                    panel.browseSorting = "toplist"
                    WallpaperManager.search("", "toplist", 1)
                  }
                }

                FocusButton {
                  text: "Hot"
                  backgroundColor: Theme.bgCard
                  hoverColor: Theme.bgCardHover
                  onClicked: {
                    panel.browseSorting = "hot"
                    WallpaperManager.search("", "hot", 1)
                  }
                }

                FocusButton {
                  text: "Latest"
                  backgroundColor: Theme.bgCard
                  hoverColor: Theme.bgCardHover
                  onClicked: {
                    panel.browseSorting = "date_added"
                    WallpaperManager.search("", "date_added", 1)
                  }
                }

                FocusButton {
                  text: "Random"
                  backgroundColor: Theme.bgCard
                  hoverColor: Theme.bgCardHover
                  onClicked: {
                    panel.browseSorting = "random"
                    WallpaperManager.search("", "random", 1)
                  }
                }
              }
            }

            // -- Preview overlay --------------------------------------------

            Item {
              id: previewContainer
              anchors.fill: parent
              visible: panel.previewOpen

              Column {
                anchors.fill: parent
                spacing: 12

                // Top bar
                Row {
                  spacing: 12
                  width: parent.width

                  FocusButton {
                    text: "Back"
                    width: 100
                    onClicked: panel.closePreview()
                  }

                  Item { width: 1; height: 1 }

                  // Wallpaper info (browse only)
                  Text {
                    visible: !panel.previewIsLocal && panel.previewItem
                    text: panel.previewItem ? (panel.previewItem.resolution + "  |  " + panel.previewItem.category) : ""
                    color: Theme.textSecondary
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Preview image
                Item {
                  width: parent.width
                  height: Math.max(100, parent.height - 110)
                  clip: true

                  Image {
                    id: previewImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: {
                      if (!panel.previewOpen) return ""
                      if (panel.previewIsLocal)
                        return "file://" + panel.previewSource
                      return panel.previewSource
                    }
                    sourceSize.width: parent.width * 2
                    asynchronous: true
                    cache: false
                  }

                  // Loading placeholder
                  Text {
                    anchors.centerIn: parent
                    text: "Loading..."
                    color: Theme.textMuted
                    font.pixelSize: 15
                    visible: previewImage.status === Image.Loading
                  }
                }

                // Action buttons
                Row {
                  spacing: 12
                  anchors.horizontalCenter: parent.horizontalCenter

                  FocusButton {
                    text: panel.previewIsLocal ? "Apply wallpaper" : "Download & apply"
                    backgroundColor: Theme.accent
                    textColor: Theme.bgDeep
                    textHoverColor: Theme.bgDeep
                    onClicked: {
                      if (panel.previewIsLocal) {
                        WallpaperManager.applyWallpaper(panel.previewSource)
                      } else if (panel.previewItem) {
                        WallpaperManager.downloadAndApply(panel.previewItem.fullPath, panel.previewItem.id)
                      }
                      panel.closePreview()
                    }
                  }

                  FocusButton {
                    text: "Delete"
                    visible: panel.previewIsLocal
                    backgroundColor: Theme.danger
                    textColor: Theme.bgBase
                    textHoverColor: Theme.bgBase
                    hoverColor: Qt.darker(Theme.danger, 1.2)
                    onClicked: {
                      WallpaperManager.deleteFile(panel.previewSource)
                      panel.closePreview()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
