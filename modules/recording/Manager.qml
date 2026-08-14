pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: recordingManager

  // General (profile-independent) settings
  property alias processName: generalAdapter.processName
  property alias screenshotDir: generalAdapter.screenshotDir
  property alias screencastDir: generalAdapter.screencastDir
  property alias imagePreviewer: generalAdapter.imagePreviewer
  property alias videoPreviewer: generalAdapter.videoPreviewer

  ModuleConfig {
    moduleId: "recording"
    scope: "general"
    adapter: JsonAdapter {
      id: generalAdapter
      property string processName: "gpu-screen-recorder"
      property string screenshotDir: (Quickshell.env("HOME") || "") + "/Pictures/screenshots"
      property string screencastDir: (Quickshell.env("HOME") || "") + "/Videos/screencasts"
      property string imagePreviewer: "sushi"
      property string videoPreviewer: "sushi"
    }
  }

  // Recording detection (polling)
  property bool isRecording: false
  property bool _stopping: false

  Timer {
    interval: 2000
    running: !recordingManager._stopping
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      _checkRecordingProc.command = ["pidof", recordingManager.processName]
      _checkRecordingProc.running = true
    }
  }

  Process {
    id: _checkRecordingProc
    onExited: function(exitCode, exitStatus) {
      recordingManager.isRecording = (exitCode === 0)
    }
  }

  function stopRecording() {
    _stopping = true
    isRecording = false
    _stopProc.command = ["pkill", "-f", "-SIGINT", processName]
    _stopProc.running = true
  }

  // Wait for the process to actually exit before resuming polling
  Process {
    id: _stopProc
    onExited: function(exitCode, exitStatus) {
      _waitProc.command = ["bash", "-c", 'while pidof "$1" > /dev/null 2>&1; do sleep 0.2; done', "wait-recording", recordingManager.processName]
      _waitProc.running = true
    }
  }

  // Once the process has fully exited, copy the path and resume polling
  Process {
    id: _waitProc
    onExited: function(exitCode, exitStatus) {
      recordingManager.isRecording = false
      recordingManager._stopping = false
      _copyLatestPathProc.running = true
    }
  }

  // Copy the absolute path of the latest screencast to clipboard
  Process {
    id: _copyLatestPathProc
    command: ["bash", "-c", "ls -t \"$HOME/Videos/screencasts/\"*.mp4 2>/dev/null | head -1 | tr -d '\\n' | wl-copy"]
  }

  // Panel state
  readonly property bool panelOpen: OverlayManager.isOpen("recording")
  onPanelOpenChanged: {
    if (panelOpen) {
      refreshFiles()
    } else {
      screenshots = []
      screenshotCount = 0
      screencasts = []
      screencastCount = 0
      _pendingThumbnails = ({})
      _thumbnailQueue = []
    }
  }

  // File lists (sorted newest first)
  property var screenshots: []
  property int screenshotCount: 0
  property var screencasts: []
  property int screencastCount: 0

  // Thumbnail cache directory
  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dotshell/thumbnails"

  // Signals for panel to react to file operations
  signal filesRefreshed()
  signal fileRenamed(string oldPath, string newPath)

  // Panel toggle functions
  function togglePanel() {
    OverlayManager.toggle("recording")
  }

  function closePanel() {
    OverlayManager.close("recording")
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
    stdout: StdioCollector {}
    onExited: {
      var lines = listScreenshotsProc.stdout.text.trim().split("\n").filter(function(l) { return l.length > 0 })
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
    stdout: StdioCollector {}
    onExited: {
      var lines = listScreencastsProc.stdout.text.trim().split("\n").filter(function(l) { return l.length > 0 })
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

  // Thumbnail generation for grid previews
  function getThumbnailPath(filePath) {
    return cacheDir + "/" + Qt.md5(filePath) + ".png"
  }

  property var _pendingThumbnails: ({})
  property var _thumbnailQueue: []
  property int _activeThumbnailJobs: 0
  readonly property int _maxThumbnailJobs: 3
  property bool _thumbnailCacheReady: false

  Process {
    command: ["mkdir", "-p", recordingManager.cacheDir]
    running: true
    onExited: function(exitCode) {
      recordingManager._thumbnailCacheReady = exitCode === 0
      recordingManager._drainThumbnailQueue()
    }
  }

  function requestThumbnail(filePath) {
    if (_pendingThumbnails[filePath]) return
    _pendingThumbnails[filePath] = true
    _thumbnailQueue.push(filePath)
    _drainThumbnailQueue()
  }

  function _drainThumbnailQueue() {
    if (!_thumbnailCacheReady) return
    while (_activeThumbnailJobs < _maxThumbnailJobs && _thumbnailQueue.length > 0)
      _startThumbnailJob(_thumbnailQueue.shift())
  }

  function _startThumbnailJob(filePath) {
    _activeThumbnailJobs++
    var thumbPath = getThumbnailPath(filePath)
    var proc = thumbComponent.createObject(recordingManager, {
      filePath: filePath,
      thumbPath: thumbPath
    })
    var seekArgs = /\.(mp4|mkv|webm|avi|mov)$/i.test(filePath) ? ["-ss", "00:00:01"] : []
    proc.command = ["ffmpeg", "-y"].concat(seekArgs, [
      "-i", filePath, "-vframes", "1", "-vf", "scale=320:-1", thumbPath
    ])
    proc.running = true
  }

  Component {
    id: thumbComponent
    Process {
      property string filePath: ""
      property string thumbPath: ""
      stderr: StdioCollector {}
      onExited: function(exitCode) {
        recordingManager._activeThumbnailJobs--
        delete recordingManager._pendingThumbnails[filePath]
        if (exitCode === 0)
          recordingManager.thumbnailReady(filePath, thumbPath)
        recordingManager._drainThumbnailQueue()
        destroy()
      }
    }
  }

  signal thumbnailReady(string filePath, string thumbPath)

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
    stdout: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var secs = Math.floor(parseFloat(durationProc.stdout.text.trim()))
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
    deleteFiles([filePath])
  }

  function deleteFiles(paths) {
    if (!paths || paths.length === 0) return
    var targets = []
    for (var i = 0; i < paths.length; i++) {
      targets.push(paths[i])
      targets.push(getThumbnailPath(paths[i]))
      targets.push(getDetailThumbnailPath(paths[i]))
    }
    deleteFilesProc.command = ["rm", "-f"].concat(targets)
    deleteFilesProc.running = true
  }

  Process {
    id: deleteFilesProc
    onExited: recordingManager.refreshFiles()
  }

  function deleteAll(type) {
    deleteFiles(type === "screenshots" ? screenshots : screencasts)
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
    copyPathProc.command = ["wl-copy", filePath]
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
  Component.onCompleted: OverlayManager.register("recording", "Screen recording files panel")
}
