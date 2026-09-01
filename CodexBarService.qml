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
  readonly property string baseUrl: "http://" + host + ":" + port

  // stopped -> starting -> ready; error always recovers through a health probe.
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
  property string _serveError: ""

  function settingValue(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function boundedSetting(name, fallback, minimum, maximum) {
    var value = Number(settingValue(name, fallback))
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, Math.round(value)))
  }

  function conciseError(value, fallback) {
    var text = String(value || "").trim().replace(/\s+/g, " ")
    if (text === "") text = fallback
    return text.length > 180 ? text.slice(0, 177) + "…" : text
  }

  function curlCommand(path) {
    return [
      "curl", "--silent", "--show-error", "--fail",
      "--connect-timeout", String(requestTimeoutSec),
      "--max-time", String(requestTimeoutSec),
      "--header", "Accept: application/json",
      baseUrl + path
    ]
  }

  function probe() {
    if (_shuttingDown || healthProcess.running) return
    if (status === "stopped" || status === "error") status = "starting"
    healthProcess.command = curlCommand("/health")
    healthProcess.running = true
  }

  function startOwnedServer() {
    if (_shuttingDown || serveProcess.running) return
    status = "starting"
    lastError = ""
    _serveError = ""
    ownsProcess = true
    serveProcess.command = [
      "/usr/bin/env", "codexbar", "serve",
      "--host", host,
      "--port", String(port),
      "--refresh-interval", String(serviceRefreshIntervalSec),
      "--request-timeout", String(requestTimeoutSec),
      "--identity", "redacted",
      "--log-level", "error"
    ]
    serveProcess.running = true
    readinessTimer.restart()
  }

  function installCli() {
    if (_shuttingDown || installProcess.running) return
    installProcess.command = [
      "/usr/bin/env", "omarchy-launch-floating-terminal-with-presentation",
      "yay -S --needed codexbar-cli"
    ]
    installProcess.running = true
  }

  function acceptHealth(raw) {
    try {
      var health = JSON.parse(String(raw || ""))
      if (!health || health.status !== "ok") return false
      serverVersion = String(health.version || "")
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

  function handleFailedProbe(message) {
    if (_shuttingDown) return
    if (ownsProcess && serveProcess.running) {
      status = "starting"
      lastError = conciseError(message, "Waiting for CodexBar to become ready")
      readinessTimer.restart()
      return
    }
    startOwnedServer()
  }

  function refreshNow() {
    if (_shuttingDown) return
    if (status !== "ready") { probe(); return }
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
      if (!Array.isArray(parsed) && !(parsed && (Array.isArray(parsed.providers) || Array.isArray(parsed.data) || parsed.provider)))
        throw new Error("unexpected response shape")
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
      costPayload = parsed
      costError = ""
      updateProviders()
      return true
    } catch (error) {
      costError = "Cost data is temporarily unavailable"
      return false
    }
  }

  function recordServeError(line) {
    var text = String(line || "").trim()
    if (text !== "") _serveError = conciseError(text, "CodexBar failed to start")
  }

  Component.onCompleted: probe()

  Component.onDestruction: {
    _shuttingDown = true
    refreshTimer.stop()
    reconnectTimer.stop()
    readinessTimer.stop()
    healthProcess.running = false
    usageProcess.running = false
    costProcess.running = false
    installProcess.running = false
    if (ownsProcess && serveProcess.running) serveProcess.running = false
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
    stderr: StdioCollector { id: healthStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var output = String(healthStdout.text || "")
      if (exitCode === 0 && root.acceptHealth(output)) return
      root.handleFailedProbe(String(healthStderr.text || output || ""))
    }
  }

  Process {
    id: serveProcess
    running: false
    command: []
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line || "").indexOf("listening on") >= 0) Qt.callLater(root.probe)
      }
    }
    stderr: SplitParser { onRead: function(line) { root.recordServeError(line) } }
    onExited: function(exitCode) {
      var expected = root._shuttingDown
      root.ownsProcess = false
      if (expected) return
      readinessTimer.stop()
      root.cliMissing = exitCode === 127
      root.lastError = root.conciseError(root._serveError, root.cliMissing
        ? "codexbar is not installed or is not on PATH"
        : "CodexBar service stopped unexpectedly")
      root.status = "error"
      reconnectTimer.restart()
    }
  }

  Process {
    id: installProcess
    running: false
    command: []
    onExited: root.probe()
  }

  Process {
    id: usageProcess
    running: false
    command: []
    stdout: StdioCollector { id: usageStdout; waitForEnd: true }
    stderr: StdioCollector { id: usageStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root._usageFinished = true
      if (exitCode === 0) root.parseUsage(String(usageStdout.text || ""))
      else {
        root.status = "error"
        root.lastError = root.conciseError(usageStderr.text, "Could not read CodexBar usage")
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
    stderr: StdioCollector { id: costStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root._costFinished = true
      if (exitCode === 0) root.parseCost(String(costStdout.text || ""))
      else root.costError = root.conciseError(costStderr.text, "Cost data is temporarily unavailable")
      root.finishRefreshPart()
    }
  }
}
