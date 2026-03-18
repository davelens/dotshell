pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: wallpaperManager

  // -- General settings (profile-independent) -------------------------------

  readonly property string generalStatePath: DataManager.getGeneralStatePath("wallpaper")
  property alias wallpaperDir: generalAdapter.wallpaperDir
  property alias apiKey: generalAdapter.apiKey
  property alias defaultCategories: generalAdapter.defaultCategories
  property alias defaultPurity: generalAdapter.defaultPurity
  property alias minResolution: generalAdapter.minResolution

  FileView {
    id: generalSettingsFile
    path: DataManager.dataDirReady ? wallpaperManager.generalStatePath : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoadFailed: writeAdapter()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: generalAdapter
      property string wallpaperDir: (Quickshell.env("HOME") || "") + "/Pictures/wallpapers"
      property string apiKey: ""
      property string defaultCategories: "111"
      property string defaultPurity: "100"
      property string minResolution: "1920x1080"
    }
  }

  // -- Profile-scoped state (current wallpaper per profile) -----------------

  readonly property string statePath: DataManager.getStatePath("wallpaper")
  property string currentWallpaper: ""

  FileView {
    id: stateFile
    path: DataManager.ready ? wallpaperManager.statePath : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoadFailed: writeAdapter()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: stateAdapter
      property string currentWallpaper: ""
    }
  }

  // Sync adapter -> manager property
  Connections {
    target: stateAdapter
    function onCurrentWallpaperChanged() {
      wallpaperManager.currentWallpaper = stateAdapter.currentWallpaper
    }
  }

  // Restore wallpaper on profile load
  Connections {
    target: DataManager
    function onReadyChanged() {
      if (DataManager.ready && stateAdapter.currentWallpaper) {
        wallpaperManager.applyWallpaper(stateAdapter.currentWallpaper)
      }
    }
  }

  // -- Panel state ----------------------------------------------------------

  property bool panelOpen: false

  function togglePanel() {
    if (panelOpen) closePanel()
    else openPanel()
  }

  function openPanel() {
    panelOpen = true
    refreshLocalFiles()
  }

  function closePanel() {
    panelOpen = false
  }

  // -- Local files ----------------------------------------------------------

  property var localFiles: []
  property int localFileCount: 0

  signal localFilesRefreshed()

  function refreshLocalFiles() {
    var dir = wallpaperDir
    listLocalProc.command = ["sh", "-c",
      "ls -1t '" + dir + "' 2>/dev/null | grep -iE '\\.(png|jpg|jpeg|webp|bmp)$' || true"
    ]
    listLocalProc.running = true
  }

  Process {
    id: listLocalProc
    property string output: ""
    onStarted: { output = "" }
    stdout: SplitParser {
      onRead: data => { listLocalProc.output += data + "\n" }
    }
    onExited: {
      var lines = listLocalProc.output.trim().split("\n").filter(function(l) { return l.length > 0 })
      var dir = wallpaperManager.wallpaperDir
      var result = []
      for (var i = 0; i < lines.length; i++) {
        result.push(dir + "/" + lines[i])
      }
      wallpaperManager.localFiles = result
      wallpaperManager.localFileCount = result.length
      wallpaperManager.localFilesRefreshed()
    }
  }

  // -- Wallhaven API --------------------------------------------------------

  property var searchResults: []
  property int searchResultCount: 0
  property int currentPage: 1
  property int lastPage: 1
  property bool searching: false
  property string lastQuery: ""
  property string lastSorting: "toplist"

  signal searchCompleted()

  function search(query, sorting, page) {
    if (searching) return
    lastQuery = query || ""
    lastSorting = sorting || "toplist"
    currentPage = page || 1
    searching = true

    var url = "https://wallhaven.cc/api/v1/search?"
    var params = []

    if (lastQuery) params.push("q=" + lastQuery)
    params.push("categories=" + defaultCategories)
    params.push("purity=" + defaultPurity)
    if (minResolution) params.push("atleast=" + minResolution)
    params.push("sorting=" + lastSorting)
    params.push("page=" + currentPage)
    if (apiKey) params.push("apikey=" + apiKey)

    url += params.join("&")

    searchProc.output = ""
    searchProc.command = ["curl", "-s", "-f", url]
    searchProc.running = true
  }

  function searchNextPage() {
    if (currentPage < lastPage) {
      search(lastQuery, lastSorting, currentPage + 1)
    }
  }

  function searchPreviousPage() {
    if (currentPage > 1) {
      search(lastQuery, lastSorting, currentPage - 1)
    }
  }

  Process {
    id: searchProc
    property string output: ""
    onStarted: { output = "" }
    stdout: SplitParser {
      onRead: data => { searchProc.output += data + "\n" }
    }
    onExited: function(exitCode) {
      wallpaperManager.searching = false
      if (exitCode !== 0) {
        wallpaperManager.searchResults = []
        wallpaperManager.searchResultCount = 0
        wallpaperManager.searchCompleted()
        return
      }

      try {
        var json = JSON.parse(searchProc.output)
        var results = []
        for (var i = 0; i < json.data.length; i++) {
          var item = json.data[i]
          results.push({
            id: item.id,
            url: item.url,
            thumbSmall: item.thumbs.small,
            thumbLarge: item.thumbs.large,
            thumbOriginal: item.thumbs.original,
            fullPath: item.path,
            resolution: item.resolution,
            fileSize: item.file_size,
            fileType: item.file_type,
            category: item.category,
            purity: item.purity,
            colors: item.colors || [],
            ratio: item.ratio
          })
        }
        wallpaperManager.searchResults = results
        wallpaperManager.searchResultCount = results.length
        wallpaperManager.currentPage = json.meta.current_page
        wallpaperManager.lastPage = json.meta.last_page
      } catch(e) {
        console.log("wallpaper: failed to parse search response:", e)
        wallpaperManager.searchResults = []
        wallpaperManager.searchResultCount = 0
      }
      wallpaperManager.searchCompleted()
    }
  }

  // -- Download -------------------------------------------------------------

  property bool downloading: false
  property string downloadingId: ""

  signal downloadCompleted(string localPath)
  signal downloadFailed(string wallpaperId)

  function downloadAndApply(wallpaperUrl, wallpaperId) {
    if (downloading) return

    // Determine filename from URL
    var fileName = wallpaperUrl.substring(wallpaperUrl.lastIndexOf("/") + 1)
    var localPath = wallpaperDir + "/" + fileName

    downloading = true
    downloadingId = wallpaperId

    downloadProc.localPath = localPath
    downloadProc.command = ["sh", "-c",
      "mkdir -p '" + wallpaperDir + "' && " +
      "curl -s -f -o '" + localPath + "' '" + wallpaperUrl + "'"
    ]
    downloadProc.running = true
  }

  Process {
    id: downloadProc
    property string localPath: ""
    onExited: function(exitCode) {
      wallpaperManager.downloading = false
      var id = wallpaperManager.downloadingId
      wallpaperManager.downloadingId = ""
      if (exitCode === 0) {
        wallpaperManager.applyWallpaper(localPath)
        wallpaperManager.refreshLocalFiles()
        wallpaperManager.downloadCompleted(localPath)
      } else {
        wallpaperManager.downloadFailed(id)
      }
    }
  }

  // -- Apply wallpaper --------------------------------------------------------

  function applyWallpaper(path) {
    if (!path) return
    currentWallpaper = path
    stateAdapter.currentWallpaper = path
    stateFile.writeAdapter()

    if (Compositor.resolvedBackend === "sway") {
      // Sway manages swaybg internally via its own IPC
      swayApplyProc.command = ["swaymsg", "output", "*", "bg", path, "fill"]
      swayApplyProc.running = true
    } else {
      // Niri (and other compositors): manage swaybg directly.
      // Kill any existing instance, then start a fresh one.
      swaybgRestartProc.wallpaperPath = path
      swaybgRestartProc.command = ["sh", "-c",
        "pkill -x swaybg; sleep 0.1; swaybg -o '*' -i '" + path + "' -m fill &"
      ]
      swaybgRestartProc.running = true
    }
  }

  Process {
    id: swayApplyProc
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.log("wallpaper: swaymsg failed to set wallpaper")
      }
    }
  }

  Process {
    id: swaybgRestartProc
    property string wallpaperPath: ""
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.log("wallpaper: swaybg failed to start for", wallpaperPath)
      }
    }
  }

  // -- Delete local file ----------------------------------------------------

  function deleteFile(path) {
    deleteProc.filePath = path
    deleteProc.command = ["rm", "-f", path]
    deleteProc.running = true
  }

  Process {
    id: deleteProc
    property string filePath: ""
    onExited: function(exitCode) {
      if (exitCode === 0) {
        wallpaperManager.refreshLocalFiles()
      }
    }
  }

  // -- IPC handler ----------------------------------------------------------

  IpcHandler {
    target: "wallpaper"

    function browse(): void {
      wallpaperManager.togglePanel()
    }

    function set(path: string): void {
      wallpaperManager.applyWallpaper(path)
    }
  }
}
