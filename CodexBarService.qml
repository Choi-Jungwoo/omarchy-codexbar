import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  readonly property string host: "127.0.0.1"
  readonly property int port: boundedSetting("serverPort", 49273, 1, 65535)
  readonly property int requestTimeoutSec: boundedSetting("requestTimeoutSec", 8, 2, 60)
  readonly property int refreshIntervalSec: boundedSetting("refreshIntervalSec", 60, 30, 3600)
  readonly property int serviceRefreshIntervalSec: boundedSetting("serviceRefreshIntervalSec", 300, 30, 3600)
  readonly property int maxResponseBytes: 1048576
  readonly property string baseUrl: "http://" + host + ":" + port

  // stopped -> starting -> ready; error always recovers by restarting our authenticated service.
  property string status: "stopped"
  property string lastError: ""
  property string costError: ""
  property string serverVersion: ""
  property bool ownsProcess: false
  property bool cliMissing: false
  property bool refreshing: false
  property var providers: []
  property var usagePayload: []
  property var costPayload: []
  property string lastUpdatedAt: ""

  property bool _shuttingDown: false
  property bool _refreshQueued: false
  property bool _usageFinished: true
  property bool _costFinished: true
  property string _dashboardToken: ""

  function settingValue(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function boundedSetting(name, fallback, minimum, maximum) {
    var value = Number(settingValue(name, fallback))
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, Math.round(value)))
  }

  function curlCommand(path, authenticated) {
    var command = [
      "/usr/bin/curl", "--disable", "--silent", "--fail",
      "--noproxy", "*", "--proto", "=http",
      "--connect-timeout", String(requestTimeoutSec),
      "--max-time", String(requestTimeoutSec),
      "--max-filesize", String(maxResponseBytes),
      "--header", "Accept: application/json"
    ]
    if (authenticated) command.push("--header", "Authorization: Bearer " + _dashboardToken)
    command.push(baseUrl + path)
    return command
  }

  function initialize(token) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(token)) {
      status = "error"
      lastError = "Could not create a private CodexBar session"
      return
    }
    _dashboardToken = token
    probe()
  }

  function probe() {
    if (_shuttingDown || healthProcess.running || cliCheckProcess.running) return
    if (status === "stopped" || status === "error") status = "starting"
    if (!ownsProcess || !serveProcess.running) {
      cliCheckProcess.running = true
      return
    }
    healthProcess.command = curlCommand("/dashboard/v1/snapshot", true)
    healthProcess.running = true
  }

  function startOwnedServer() {
    if (_shuttingDown || serveProcess.running) return
    status = "starting"
    lastError = ""
    ownsProcess = true
    serveProcess.command = [
      "/usr/bin/codexbar", "serve",
      "--host", host,
      "--port", String(port),
      "--refresh-interval", String(serviceRefreshIntervalSec),
      "--request-timeout", String(requestTimeoutSec),
      "--identity", "redacted",
      "--log-level", "error"
    ]
    serveProcess.running = true
  }

  function acceptIdentity(raw) {
    try {
      var snapshot = JSON.parse(String(raw || ""))
      if (!snapshot || Array.isArray(snapshot) || typeof snapshot !== "object"
          || snapshot.schemaVersion !== 1
          || !snapshot.host || Array.isArray(snapshot.host) || typeof snapshot.host !== "object"
          || typeof snapshot.host.codexBarVersion !== "string"
          || snapshot.host.codexBarVersion.length < 1 || snapshot.host.codexBarVersion.length > 64
          || !Array.isArray(snapshot.providers) || snapshot.providers.length > 128)
        return false
      for (var i = 0; i < snapshot.providers.length; i++) {
        var provider = snapshot.providers[i]
        if (!provider || Array.isArray(provider) || typeof provider !== "object"
            || !Model.isProviderId(provider.id))
          return false
      }
      serverVersion = snapshot.host.codexBarVersion
      lastError = ""
      cliMissing = false
      status = "ready"
      reconnectTimer.stop()
      refreshNow()
      return true
    } catch (error) {
      return false
    }
  }

  function handleFailedProbe() {
    if (_shuttingDown) return
    if (ownsProcess && serveProcess.running) {
      status = "starting"
      lastError = "Waiting for the authenticated CodexBar service"
      readinessTimer.restart()
      return
    }
    probe()
  }

  function refreshNow() {
    if (_shuttingDown) return
    if (status !== "ready") { probe(); return }
    if (!ownsProcess || !serveProcess.running) {
      status = "error"
      lastError = "CodexBar service stopped unexpectedly"
      reconnectTimer.restart()
      return
    }
    if (usageProcess.running || costProcess.running) {
      _refreshQueued = true
      return
    }
    refreshing = true
    _refreshQueued = false
    _usageFinished = false
    _costFinished = false
    usageProcess.command = curlCommand("/usage?provider=all")
    costProcess.command = curlCommand("/cost")
    usageProcess.running = true
    costProcess.running = true
  }

  function updateProviders() {
    providers = Model.normalizeProviders(usagePayload, costPayload)
  }

  function finishRefreshPart() {
    if (!_usageFinished || !_costFinished) return
    refreshing = false
    if (_refreshQueued) Qt.callLater(root.refreshNow)
  }

  function parseUsage(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      Model.validateProviderRecords(parsed)
      usagePayload = parsed
      updateProviders()
      lastUpdatedAt = new Date().toISOString()
      lastError = ""
      status = "ready"
      return true
    } catch (error) {
      lastError = "CodexBar usage response could not be read"
      status = "error"
      reconnectTimer.restart()
      return false
    }
  }

  function parseCost(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      Model.validateProviderRecords(parsed)
      costPayload = parsed
      costError = ""
      updateProviders()
      return true
    } catch (error) {
      costError = "Cost data is temporarily unavailable"
      return false
    }
  }

  Component.onDestruction: {
    _shuttingDown = true
    refreshTimer.stop()
    reconnectTimer.stop()
    readinessTimer.stop()
    healthProcess.running = false
    cliCheckProcess.running = false
    usageProcess.running = false
    costProcess.running = false
    if (ownsProcess && serveProcess.running) serveProcess.running = false
  }

  FileView {
    path: "/proc/sys/kernel/random/uuid"
    printErrors: false
    onLoaded: root.initialize(String(text()).trim())
    onLoadFailed: function() {
      root.status = "error"
      root.lastError = "Could not create a private CodexBar session"
    }
  }

  Timer {
    id: readinessTimer
    interval: 350
    repeat: false
    onTriggered: root.probe()
  }

  Timer {
    id: reconnectTimer
    interval: 5000
    repeat: false
    onTriggered: root.probe()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: root.status === "ready"
    onTriggered: root.refreshNow()
  }

  Process {
    id: healthProcess
    running: false
    command: []
    stdout: StdioCollector { id: healthStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var output = String(healthStdout.text || "")
      if (exitCode === 0 && root.acceptIdentity(output)) return
      root.handleFailedProbe()
    }
  }

  Process {
    id: cliCheckProcess
    running: false
    command: ["/usr/bin/test", "-x", "/usr/bin/codexbar"]
    onExited: function(exitCode) {
      if (root._shuttingDown) return
      root.cliMissing = exitCode !== 0
      if (root.cliMissing) {
        root.status = "error"
        root.lastError = "CodexBar CLI is not installed at /usr/bin/codexbar"
        reconnectTimer.restart()
      } else root.startOwnedServer()
    }
  }

  Process {
    id: serveProcess
    running: false
    command: []
    environment: ({ "CODEXBAR_DASHBOARD_TOKEN": root._dashboardToken })
    onStarted: readinessTimer.restart()
    onExited: function(exitCode) {
      var expected = root._shuttingDown
      root.ownsProcess = false
      if (expected) return
      readinessTimer.stop()
      root.lastError = "CodexBar service stopped unexpectedly"
      root.status = "error"
      reconnectTimer.restart()
    }
  }

  Process {
    id: usageProcess
    running: false
    command: []
    stdout: StdioCollector { id: usageStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root._usageFinished = true
      if (exitCode === 0) root.parseUsage(String(usageStdout.text || ""))
      else {
        root.status = "error"
        root.lastError = "Could not read CodexBar usage"
        reconnectTimer.restart()
      }
      root.finishRefreshPart()
    }
  }

  Process {
    id: costProcess
    running: false
    command: []
    stdout: StdioCollector { id: costStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root._costFinished = true
      if (exitCode === 0) root.parseCost(String(costStdout.text || ""))
      else root.costError = "Cost data is temporarily unavailable"
      root.finishRefreshPart()
    }
  }
}
