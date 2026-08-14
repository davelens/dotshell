pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: thumbnailCache

  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dotshell/thumbnails"
  readonly property int maxJobs: 3

  property var _pending: ({})
  property var _queue: []
  property int _activeJobs: 0
  property bool _cacheReady: false

  signal thumbnailReady(string thumbnailPath)

  function _normalizePath(source) {
    if (!source) return ""
    var path = String(source)
    return path.startsWith("file://") ? path.substring(7) : path
  }

  function thumbnailPath(source) {
    var path = _normalizePath(source)
    return path ? cacheDir + "/" + Qt.md5(path) + ".png" : ""
  }

  function thumbnailUrl(source) {
    var path = thumbnailPath(source)
    return path ? "file://" + path : ""
  }

  function request(source) {
    var path = _normalizePath(source)
    if (!path || _pending[path]) return
    _pending[path] = true
    _queue.push(path)
    _drainQueue()
  }

  function _drainQueue() {
    if (!_cacheReady) return
    while (_activeJobs < maxJobs && _queue.length > 0)
      _startJob(_queue.shift())
  }

  function _startJob(sourcePath) {
    var outputPath = thumbnailPath(sourcePath)
    var process = thumbnailProcess.createObject(thumbnailCache, {
      sourcePath: sourcePath,
      thumbnailPath: outputPath
    })
    var seekArgs = /\.(mp4|mkv|webm|avi|mov)$/i.test(sourcePath) ? ["-ss", "00:00:01"] : []
    process.command = ["ffmpeg", "-y"].concat(seekArgs, [
      "-i", sourcePath, "-vframes", "1", "-vf", "scale=320:-1", outputPath
    ])
    _activeJobs++
    process.running = true
  }

  Process {
    command: ["mkdir", "-p", thumbnailCache.cacheDir]
    running: true
    onExited: function(exitCode) {
      thumbnailCache._cacheReady = exitCode === 0
      thumbnailCache._drainQueue()
    }
  }

  Component {
    id: thumbnailProcess

    Process {
      property string sourcePath: ""
      property string thumbnailPath: ""
      stderr: StdioCollector {}

      onExited: function(exitCode) {
        thumbnailCache._activeJobs--
        delete thumbnailCache._pending[sourcePath]
        if (exitCode === 0)
          thumbnailCache.thumbnailReady(thumbnailPath)
        thumbnailCache._drainQueue()
        destroy()
      }
    }
  }
}
