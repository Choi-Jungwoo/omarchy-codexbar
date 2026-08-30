import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool active: false

  readonly property string endpoint: "https://codexradar.com/api/radar-insights"
  readonly property string metricsEndpoint: "https://codexradar.com/api/intelligence-efficiency-metrics"
  readonly property int requestTimeoutSec: boundedSetting("requestTimeoutSec", 8, 2, 60)
  readonly property int refreshIntervalSec: boundedSetting("radarRefreshIntervalSec", 300, 60, 3600)

  property string status: "idle"
  property string lastError: ""
  property bool refreshing: false
  property var groups: []
  property string generatedAt: ""
  property string sourceUpdatedAt: ""
  property double lastRequestAtMs: 0
  property bool _shuttingDown: false
  property bool _recommendationsFinished: true
  property bool _metricsFinished: true
  property string _recommendationsRaw: ""
  property string _metricsRaw: ""
  property string _requestError: ""

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

  function refreshIfStale() {
    if (lastRequestAtMs === 0 || Date.now() - lastRequestAtMs >= refreshIntervalSec * 1000) refreshNow()
  }

  function curlCommand(url) {
    return [
      "curl", "--silent", "--show-error", "--fail",
      "--connect-timeout", String(requestTimeoutSec),
      "--max-time", String(requestTimeoutSec),
      "--header", "Accept: application/json",
      "--user-agent", "omarchy-codexbar/0.2",
      url
    ]
  }

  function refreshNow() {
    if (_shuttingDown || requestProcess.running || metricsProcess.running) return
    refreshing = true
    if (groups.length === 0) status = "loading"
    _recommendationsFinished = false
    _metricsFinished = false
    _recommendationsRaw = ""
    _metricsRaw = ""
    _requestError = ""
    requestProcess.command = curlCommand(endpoint)
    metricsProcess.command = curlCommand(metricsEndpoint)
    requestProcess.running = true
    metricsProcess.running = true
  }

  function parseResponse(raw, metricsRaw) {
    try {
      var metrics = null
      try { metrics = JSON.parse(String(metricsRaw || "")) } catch (metricsError) {}
      var normalized = Model.normalizeRadarInsights(JSON.parse(String(raw || "")), metrics)
      if (!Model.hasCompleteRadarRecommendations(normalized))
        throw new Error("Codex Radar returned incomplete recommendations")
      groups = normalized.groups
      generatedAt = normalized.generatedAt
      sourceUpdatedAt = normalized.sourceUpdatedAt
      lastRequestAtMs = Date.now()
      lastError = ""
      status = "ready"
      return true
    } catch (error) {
      lastRequestAtMs = Date.now()
      lastError = "Codex Radar did not return two recommendations for every category"
      status = "error"
      return false
    }
  }

  function finishRefresh() {
    if (!_recommendationsFinished || !_metricsFinished) return
    refreshing = false
    lastRequestAtMs = Date.now()
    if (_requestError !== "") {
      status = "error"
      lastError = conciseError(_requestError, "Could not reach Codex Radar")
      return
    }
    parseResponse(_recommendationsRaw, _metricsRaw)
  }

  onActiveChanged: if (active) Qt.callLater(root.refreshIfStale)

  Component.onDestruction: {
    _shuttingDown = true
    refreshTimer.stop()
    requestProcess.running = false
    metricsProcess.running = false
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: root.active
    onTriggered: root.refreshNow()
  }

  Process {
    id: requestProcess
    running: false
    command: []
    stdout: StdioCollector { id: requestStdout; waitForEnd: true }
    stderr: StdioCollector { id: requestStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root._recommendationsFinished = true
      if (root._shuttingDown) return
      if (exitCode === 0) root._recommendationsRaw = String(requestStdout.text || "")
      else root._requestError = String(requestStderr.text || "")
      root.finishRefresh()
    }
  }

  Process {
    id: metricsProcess
    running: false
    command: []
    stdout: StdioCollector { id: metricsStdout; waitForEnd: true }
    stderr: StdioCollector { id: metricsStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root._metricsFinished = true
      if (root._shuttingDown) return
      if (exitCode === 0) root._metricsRaw = String(metricsStdout.text || "")
      else root._requestError = root.conciseError(
        String(metricsStderr.text || ""),
        "Could not load Codex Radar efficiency metrics")
      root.finishRefresh()
    }
  }
}
