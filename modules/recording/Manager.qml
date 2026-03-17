pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: recordingManager

  // General (profile-independent) settings
  readonly property string generalStatePath: DataManager.getGeneralStatePath("recording")
  property alias processName: generalAdapter.processName
  property alias screenshotDir: generalAdapter.screenshotDir
  property alias screencastDir: generalAdapter.screencastDir
  property alias imagePreviewer: generalAdapter.imagePreviewer
  property alias videoPreviewer: generalAdapter.videoPreviewer

  FileView {
    id: generalSettingsFile
    path: DataManager.dataDirReady ? recordingManager.generalStatePath : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoadFailed: writeAdapter()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: generalAdapter
      property string processName: "gpu-screen-recorder"
      property string screenshotDir: (Quickshell.env("HOME") || "") + "/Pictures/screenshots"
      property string screencastDir: (Quickshell.env("HOME") || "") + "/Videos/screencasts"
      property string imagePreviewer: "sushi"
      property string videoPreviewer: "sushi"
    }
  }

  // Panel state
  property bool panelOpen: false

  // File lists (sorted newest first)
  property var screenshots: []
  property int screenshotCount: 0
  property var screencasts: []
  property int screencastCount: 0

  // Thumbnail cache directory
  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dotshell/thumbnails"

  // Signals for panel to react to file operations
  signal filesRefreshed()
  signal fileDeleted(string path)
  signal fileRenamed(string oldPath, string newPath)

  // Panel toggle functions
  function togglePanel() {
    if (panelOpen) closePanel()
    else openPanel()
  }

  function openPanel() {
    panelOpen = true
    refreshFiles()
  }

  function closePanel() {
    panelOpen = false
  }

  // File listing
  function refreshFiles() {
    refreshScreenshots()
    refreshScreencasts()
  }

  function refreshScreenshots() {
    var dir = screenshotDir
    listScreenshotsProc.command = ["sh", "-c",
      "find '" + dir + "' -maxdepth 1 -type f -size 0 \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) -delete 2>/dev/null ; " +
      "ls -1t '" + dir + "' 2>/dev/null | grep -iE '\\.(png|jpg|jpeg|webp|bmp)$' || true"
    ]
    listScreenshotsProc.running = true
  }

  function refreshScreencasts() {
    var dir = screencastDir
    listScreencastsProc.command = ["sh", "-c",
      "find '" + dir + "' -maxdepth 1 -type f -size 0 \\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.avi' -o -iname '*.mov' \\) -delete 2>/dev/null ; " +
      "ls -1t '" + dir + "' 2>/dev/null | grep -iE '\\.(mp4|mkv|webm|avi|mov)$' || true"
    ]
    listScreencastsProc.running = true
  }

  Process {
    id: listScreenshotsProc
    property string output: ""
    onStarted: { output = "" }
    stdout: SplitParser {
      onRead: data => { listScreenshotsProc.output += data + "\n" }
    }
    onExited: {
      var lines = listScreenshotsProc.output.trim().split("\n").filter(function(l) { return l.length > 0 })
      var dir = recordingManager.screenshotDir
      var result = []
      for (var i = 0; i < lines.length; i++) {
        result.push(dir + "/" + lines[i])
      }
      recordingManager.screenshots = result
      recordingManager.screenshotCount = result.length
      recordingManager.filesRefreshed()
    }
  }

  Process {
    id: listScreencastsProc
    property string output: ""
    onStarted: { output = "" }
    stdout: SplitParser {
      onRead: data => { listScreencastsProc.output += data + "\n" }
    }
    onExited: {
      var lines = listScreencastsProc.output.trim().split("\n").filter(function(l) { return l.length > 0 })
      var dir = recordingManager.screencastDir
      var result = []
      for (var i = 0; i < lines.length; i++) {
        result.push(dir + "/" + lines[i])
      }
      recordingManager.screencasts = result
      recordingManager.screencastCount = result.length
      recordingManager.filesRefreshed()
    }
  }

  // Thumbnail generation for screencasts
  // Returns the expected cache path for a given video file
  function getThumbnailPath(videoPath) {
    // Use a hash of the video path as the thumbnail filename
    var hash = Qt.md5(videoPath)
    return cacheDir + "/" + hash + ".png"
  }

  // Request thumbnail generation (called lazily by grid delegates)
  property var _pendingThumbnails: ({})
  property var _thumbnailQueue: []
  property int _activeThumbnailJobs: 0
  readonly property int _maxThumbnailJobs: 3

  function requestThumbnail(videoPath) {
    var thumbPath = getThumbnailPath(videoPath)
    if (_pendingThumbnails[videoPath]) return // already queued or in progress
    _pendingThumbnails[videoPath] = true
    _thumbnailQueue.push(videoPath)
    _drainThumbnailQueue()
  }

  function _drainThumbnailQueue() {
    while (_activeThumbnailJobs < _maxThumbnailJobs && _thumbnailQueue.length > 0) {
      var path = _thumbnailQueue.shift()
      _startThumbnailJob(path)
    }
  }

  function _startThumbnailJob(videoPath) {
    _activeThumbnailJobs++
    var thumbPath = getThumbnailPath(videoPath)
    var proc = thumbComponent.createObject(recordingManager, {
      videoPath: videoPath,
      thumbPath: thumbPath
    })
    proc.command = ["sh", "-c",
      "mkdir -p '" + cacheDir + "' && " +
      "ffmpeg -y -i '" + videoPath + "' -vframes 1 -ss 00:00:01 -vf 'scale=320:-1' '" + thumbPath + "' 2>/dev/null"
    ]
    proc.running = true
  }

  Component {
    id: thumbComponent
    Process {
      property string videoPath: ""
      property string thumbPath: ""
      onExited: function(exitCode) {
        recordingManager._activeThumbnailJobs--
        delete recordingManager._pendingThumbnails[videoPath]
        if (exitCode === 0) {
          recordingManager.thumbnailReady(videoPath, thumbPath)
        }
        recordingManager._drainThumbnailQueue()
        destroy()
      }
    }
  }

  signal thumbnailReady(string videoPath, string thumbPath)

  // High-resolution detail thumbnail (single job, only one detail view at a time)
  function getDetailThumbnailPath(videoPath) {
    var hash = Qt.md5(videoPath)
    return cacheDir + "/" + hash + "-detail.png"
  }

  function requestDetailThumbnail(videoPath) {
    if (!videoPath) return
    var thumbPath = getDetailThumbnailPath(videoPath)
    detailThumbProc.videoPath = videoPath
    detailThumbProc.thumbPath = thumbPath
    detailThumbProc.command = ["sh", "-c",
      "mkdir -p '" + cacheDir + "' && " +
      "ffmpeg -y -i '" + videoPath + "' -vframes 1 -ss 00:00:01 -vf 'scale=1280:-1' '" + thumbPath + "' 2>/dev/null"
    ]
    detailThumbProc.running = true
  }

  Process {
    id: detailThumbProc
    property string videoPath: ""
    property string thumbPath: ""
    onExited: function(exitCode) {
      if (exitCode === 0) {
        recordingManager.detailThumbnailReady(videoPath, thumbPath)
      }
    }
  }

  signal detailThumbnailReady(string videoPath, string thumbPath)

  // Video duration via ffprobe
  function requestDuration(videoPath) {
    if (!videoPath) return
    durationProc.videoPath = videoPath
    durationProc.output = ""
    durationProc.command = ["ffprobe", "-v", "error",
      "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      videoPath
    ]
    durationProc.running = true
  }

  Process {
    id: durationProc
    property string videoPath: ""
    property string output: ""
    stdout: SplitParser {
      onRead: data => { durationProc.output += data }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var secs = Math.floor(parseFloat(durationProc.output.trim()))
      if (isNaN(secs) || secs < 0) return
      var h = Math.floor(secs / 3600)
      var m = Math.floor((secs % 3600) / 60)
      var s = secs % 60
      var formatted = h > 0
        ? h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        : m + ":" + (s < 10 ? "0" : "") + s
      recordingManager.durationReady(videoPath, formatted)
    }
  }

  signal durationReady(string videoPath, string duration)

  // File operations
  function deleteFile(filePath) {
    deleteFileProc.filePath = filePath
    deleteFileProc.command = ["rm", "-f", filePath]
    deleteFileProc.running = true
  }

  Process {
    id: deleteFileProc
    property string filePath: ""
    onExited: function(exitCode) {
      if (exitCode === 0) {
        recordingManager.fileDeleted(filePath)
        recordingManager.refreshFiles()
      }
    }
  }

  function deleteFiles(paths) {
    if (!paths || paths.length === 0) return
    var escaped = paths.map(function(p) { return "'" + p.replace(/'/g, "'\\''") + "'" })
    deleteFilesProc.command = ["sh", "-c", "rm -f " + escaped.join(" ")]
    deleteFilesProc.running = true
  }

  Process {
    id: deleteFilesProc
    onExited: {
      recordingManager.refreshFiles()
    }
  }

  function deleteAll(type) {
    var dir = (type === "screenshots") ? screenshotDir : screencastDir
    var pattern = (type === "screenshots")
      ? "\\.(png|jpg|jpeg|webp|bmp)$"
      : "\\.(mp4|mkv|webm|avi|mov)$"
    deleteAllProc.command = ["sh", "-c",
      "find '" + dir + "' -maxdepth 1 -type f | grep -iE '" + pattern + "' | xargs rm -f 2>/dev/null ; true"
    ]
    deleteAllProc.running = true
  }

  Process {
    id: deleteAllProc
    onExited: {
      recordingManager.refreshFiles()
    }
  }

  function renameFile(oldPath, newName) {
    // Preserve directory and extension, change only the base name
    var dir = oldPath.substring(0, oldPath.lastIndexOf("/"))
    var oldName = oldPath.substring(oldPath.lastIndexOf("/") + 1)
    var ext = oldName.substring(oldName.lastIndexOf("."))
    var newPath = dir + "/" + newName + ext
    renameFileProc.oldPath = oldPath
    renameFileProc.newPath = newPath
    renameFileProc.command = ["mv", oldPath, newPath]
    renameFileProc.running = true
  }

  Process {
    id: renameFileProc
    property string oldPath: ""
    property string newPath: ""
    onExited: function(exitCode) {
      if (exitCode === 0) {
        recordingManager.fileRenamed(oldPath, newPath)
        recordingManager.refreshFiles()
      }
    }
  }

  function copyPath(filePath) {
    copyPathProc.command = ["sh", "-c", "echo -n '" + filePath + "' | wl-copy"]
    copyPathProc.running = true
  }

  Process {
    id: copyPathProc
  }

  function openFile(filePath) {
    var isVideo = /\.(mp4|mkv|webm|avi|mov)$/i.test(filePath)
    var app = isVideo ? videoPreviewer : imagePreviewer
    if (!app) app = "sushi"
    closePanel()
    openFileProc.command = [app, filePath]
    openFileProc.running = true
  }

  Process {
    id: openFileProc
  }

  // IPC handler
  IpcHandler {
    target: "screen-recording"

    function files(): void {
      recordingManager.togglePanel()
    }
  }
}
