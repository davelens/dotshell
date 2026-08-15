import QtQuick

QtObject {
  id: navigator

  // The subtree searched for focusable items.
  property Item root: null

  // Per-instance navigation state.
  property var focusables: []
  property int index: -1

  // Enable showFocusRing when focusing controls that expose it.
  property bool manageFocusRing: true

  // Opt in when focused controls may live inside a Flickable.
  property bool scrollEnabled: false
  property real scrollPadding: 24

  onRootChanged: reset()

  function collect(item, result, visited) {
    if (!item || visited.indexOf(item) !== -1) return
    visited.push(item)

    if (!item.visible || item.enabled === false) return

    if (item.showFocusRing !== undefined || item.activeFocusOnTab === true)
      result.push(item)

    if (item.children) {
      for (var i = 0; i < item.children.length; i++)
        collect(item.children[i], result, visited)
    }

    // Some controls expose their visual subtree through contentItem as well
    // as children, so visited also prevents duplicate focus entries.
    if (item.contentItem)
      collect(item.contentItem, result, visited)
  }

  function refresh() {
    var result = []
    collect(root, result, [])
    focusables = result

    if (focusables.length === 0)
      index = -1
    else if (index < -1)
      index = -1
    else if (index >= focusables.length)
      index = focusables.length - 1

    return focusables
  }

  function findFlickable(item) {
    var parent = item ? item.parent : null
    while (parent) {
      if (parent.contentY !== undefined
          && parent.contentHeight !== undefined
          && parent.contentItem !== undefined
          && parent.height !== undefined)
        return parent
      parent = parent.parent
    }
    return null
  }

  function scrollToItem(item) {
    if (!scrollEnabled || !item) return false

    var flickable = findFlickable(item)
    if (!flickable || flickable.height <= 0) return false

    var mapped = item.mapToItem(flickable.contentItem, 0, 0)
    var padding = Math.max(0, scrollPadding)
    var itemTop = mapped.y
    var itemBottom = itemTop + item.height
    var visibleTop = flickable.contentY
    var visibleBottom = visibleTop + flickable.height
    var maximumY = Math.max(0, flickable.contentHeight - flickable.height)

    if (itemTop - padding < visibleTop)
      flickable.contentY = Math.max(0, Math.min(maximumY, itemTop - padding))
    else if (itemBottom + padding > visibleBottom)
      flickable.contentY = Math.max(0, Math.min(maximumY,
                                                itemBottom + padding - flickable.height))

    return true
  }

  function _focusCurrent() {
    var item = focusables[index]
    if (!item) return false

    if (item.keyboardFocus !== undefined)
      item.keyboardFocus = true
    if (manageFocusRing && item.showFocusRing !== undefined)
      item.showFocusRing = true
    if (item.forceActiveFocus)
      item.forceActiveFocus()
    scrollToItem(item)
    return true
  }

  function focusAt(targetIndex) {
    refresh()
    if (targetIndex < 0 || targetIndex >= focusables.length) return false
    index = targetIndex
    return _focusCurrent()
  }

  function focusNext() {
    refresh()
    if (focusables.length === 0) return false
    index = (index + 1) % focusables.length
    return _focusCurrent()
  }

  function focusPrevious() {
    refresh()
    if (focusables.length === 0) return false
    index = index < 0
      ? focusables.length - 1
      : (index - 1 + focusables.length) % focusables.length
    return _focusCurrent()
  }

  function reset() {
    for (var i = 0; i < focusables.length; i++) {
      var item = focusables[i]
      if (item && item.keyboardFocus !== undefined)
        item.keyboardFocus = false
    }
    index = -1
    focusables = []
  }
}
