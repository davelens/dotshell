import QtQuick
import Quickshell.Io

// Copies `source` to `target` if `target` doesn't exist.
// Fires `done` after the check/copy completes.
// Re-runs whenever `active` flips false -> true.
Item {
  id: ensure

  property string source
  property string target
  property bool active: false

  signal done()

  onActiveChanged: if (active) proc.running = true

  Process {
    id: proc
    command: ["sh", "-c",
      "test -f '" + ensure.target + "' || cp '" + ensure.source + "' '" + ensure.target + "'"]
    onExited: ensure.done()
  }
}
