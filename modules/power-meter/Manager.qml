pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: manager

  property int gpuPowerMw: 0
  property int cpuPowerMw: 0
  property int totalPowerW: 0
  property bool raplAvailable: false
  property bool gpuAvailable: false

  // RAPL state tracking
  property var _prevRapLEnergy: 0
  property bool _raplFirstSample: true

  // Base system power estimate (motherboard, RAM, storage, fans, PCIe)
  readonly property int basePowerMw: 15000

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      // Poll GPU power (no sudo needed)
      gpuProc.command = ["sh", "-c",
        "cat /sys/class/hwmon/hwmon*/power1_input 2>/dev/null | head -1"
      ]
      gpuProc.running = true

      // Poll RAPL package energy (needs sudo)
      raplProc.command = ["sudo", "sh", "-c",
        "cat /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/energy_uj 2>/dev/null"
      ]
      raplProc.running = true
    }
  }

  // GPU power reader
  Process {
    id: gpuProc
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => gpuProc.output += data + "\n"
    }
    onExited: {
      var val = parseInt(gpuProc.output.trim())
      if (val > 0) {
        manager.gpuPowerMw = Math.round(val / 1000)
        manager.gpuAvailable = true
      } else {
        // Try alternate hwmon path
        gpuProc.command = ["sh", "-c",
          "find /sys/class/hwmon -name power1_input -exec cat {} \\; 2>/dev/null | head -1"
        ]
        gpuProc.running = true
      }
    }
  }

  // RAPL energy reader
  Process {
    id: raplProc
    property string output: ""
    onStarted: output = ""
    stdout: SplitParser {
      onRead: data => raplProc.output += data + "\n"
    }
    onExited: {
      var energyUJ = parseInt(raplProc.output.trim())
      if (energyUJ > 0) {
        manager.raplAvailable = true
        if (!manager._raplFirstSample) {
          var deltaUJ = energyUJ - manager._prevRapLEnergy
          // Calculate power: delta energy / time interval
          var deltaTimeS = 2.0 // 2 second polling interval
          var powerMW = Math.round((deltaUJ / deltaTimeS) / 1000)
          if (powerMW >= 0 && powerMW < 50000) { // sanity check: < 50W max for CPU package
            manager.cpuPowerMw = powerMW
          }
        }
        manager._prevRapLEnergy = energyUJ
        manager._raplFirstSample = false
      } else {
        if (!manager.raplAvailable) {
          // Try alternate RAPL path (AMD)
          raplProc.command = ["sudo", "sh", "-c",
            "cat /sys/devices/virtual/powercap/intel-rapl:0/energy_uj 2>/dev/null"
          ]
          raplProc.running = true
        }
      }
    }
  }

  // Compute total power whenever GPU or CPU changes
  onGpuPowerMwChanged: computeTotal()
  onCpuPowerMwChanged: computeTotal()

  function computeTotal() {
    var gpuW = Math.round(manager.gpuPowerMw / 1000)
    var cpuW = manager.raplAvailable ? Math.round(manager.cpuPowerMw / 1000) : 0
    var baseW = Math.round(manager.basePowerMw / 1000)
    manager.totalPowerW = gpuW + cpuW + baseW
  }
}
