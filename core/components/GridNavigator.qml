import QtQuick

QtObject {
  id: navigator

  property int index: -1
  property int count: 0
  property int columns: 1
  property GridView gridView: null

  onCountChanged: clamp()

  // Preserve -1 as "no selection", while keeping any selection in range.
  function clamp() {
    if (count <= 0) {
      index = -1
      return false
    }
    if (index < -1)
      index = -1
    else if (index >= count)
      index = count - 1
    return index >= 0
  }

  function ensure() {
    clamp()
    if (count <= 0) return false
    if (index < 0) {
      index = 0
      scrollToCurrent()
    }
    return true
  }

  function moveLeft() {
    if (!ensure()) return false
    if (index > 0) index--
    scrollToCurrent()
    return true
  }

  function moveRight() {
    if (!ensure()) return false
    if (index < count - 1) index++
    scrollToCurrent()
    return true
  }

  function moveUp() {
    if (!ensure()) return false
    var columnCount = Math.floor(columns)
    if (columnCount <= 0) return false
    var targetIndex = index - columnCount
    if (targetIndex >= 0) index = targetIndex
    scrollToCurrent()
    return true
  }

  function moveDown() {
    if (!ensure()) return false
    var columnCount = Math.floor(columns)
    if (columnCount <= 0) return false
    var targetIndex = index + columnCount
    if (targetIndex < count) index = targetIndex
    scrollToCurrent()
    return true
  }

  function pageUp() {
    if (!ensure()) return false
    var pageSize = visiblePageSize()
    if (pageSize <= 0) return false
    index = Math.max(0, index - pageSize)
    scrollToCurrent()
    return true
  }

  function pageDown() {
    if (!ensure()) return false
    var pageSize = visiblePageSize()
    if (pageSize <= 0) return false
    index = Math.min(count - 1, index + pageSize)
    scrollToCurrent()
    return true
  }

  function visiblePageSize() {
    var columnCount = Math.floor(columns)
    if (!gridView || columnCount <= 0
        || gridView.height <= 0 || gridView.cellHeight <= 0)
      return 0
    var visibleRows = Math.max(1, Math.floor(gridView.height / gridView.cellHeight))
    return visibleRows * columnCount
  }

  function scrollToCurrent() {
    return scrollToCell(index)
  }

  function scrollToCell(targetIndex) {
    var columnCount = Math.floor(columns)
    if (!gridView || targetIndex < 0 || targetIndex >= count
        || columnCount <= 0 || gridView.height <= 0
        || gridView.cellHeight <= 0)
      return false

    var row = Math.floor(targetIndex / columnCount)
    var cellTop = row * gridView.cellHeight
    var cellBottom = cellTop + gridView.cellHeight
    var viewTop = gridView.contentY
    var viewBottom = viewTop + gridView.height
    var targetY = viewTop

    if (cellTop < viewTop)
      targetY = cellTop
    else if (cellBottom > viewBottom)
      targetY = cellBottom - gridView.height

    var maximumY = Math.max(0, gridView.contentHeight - gridView.height)
    gridView.contentY = Math.max(0, Math.min(maximumY, targetY))
    return true
  }
}
