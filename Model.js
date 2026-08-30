function asArray(value) {
  if (Array.isArray(value)) return value
  if (value && Array.isArray(value.providers)) return value.providers
  if (value && Array.isArray(value.data)) return value.data
  return value && value.provider ? [value] : []
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === "") return null
  var number = Number(value)
  return isFinite(number) ? number : null
}

function clampPercent(value) {
  var number = numberOrNull(value)
  if (number === null) return null
  return Math.max(0, Math.min(100, number))
}

function nonEmpty(value) {
  return value === null || value === undefined ? "" : String(value).trim()
}

function providerName(providerId) {
  var id = nonEmpty(providerId).toLowerCase()
  var known = {
    claude: "Claude",
    codex: "Codex",
    copilot: "Copilot",
    cursor: "Cursor",
    droid: "Droid",
    gemini: "Gemini",
    kimi: "Kimi",
    openai: "OpenAI"
  }
  if (known[id]) return known[id]
  return id.split(/[-_\s]+/).map(function(part) {
    return part === "" ? "" : part.charAt(0).toUpperCase() + part.slice(1)
  }).join(" ")
}

function titleForWindow(key, raw) {
  var explicit = nonEmpty(raw && raw.title)
  if (explicit !== "") return explicit

  var minutes = numberOrNull(raw && raw.windowMinutes)
  if (minutes !== null) {
    if (minutes >= 28 * 24 * 60) return "Monthly"
    if (minutes >= 7 * 24 * 60) return "Weekly"
    if (minutes >= 24 * 60) return minutes === 24 * 60 ? "Daily" : Math.round(minutes / 1440) + "-day window"
    if (minutes >= 60) return Math.round(minutes / 60) + "-hour window"
    if (minutes > 0) return Math.round(minutes) + "-minute window"
  }

  if (key === "primary") return "Primary limit"
  if (key === "secondary") return "Secondary limit"
  if (key === "tertiary") return "Tertiary limit"
  return "Usage limit"
}

function paceForWindow(record, key, raw) {
  var pace = record && record.pace ? record.pace : {}
  if (pace[key]) return pace[key]
  var id = nonEmpty(raw && raw.id)
  if (id !== "" && pace[id]) return pace[id]
  return null
}

function normalizedWindow(record, key, raw, order) {
  if (!raw || typeof raw !== "object") return null
  var usedPercent = clampPercent(raw.usedPercent)
  if (usedPercent === null) return null
  var pace = paceForWindow(record, key, raw)
  return {
    id: nonEmpty(raw.id) || key,
    title: titleForWindow(key, raw),
    usedPercent: usedPercent,
    remainingPercent: Math.max(0, 100 - usedPercent),
    resetsAt: nonEmpty(raw.resetsAt),
    resetDescription: nonEmpty(raw.resetDescription),
    windowMinutes: numberOrNull(raw.windowMinutes),
    paceSummary: nonEmpty(pace && pace.summary),
    paceStage: nonEmpty(pace && pace.stage),
    willLastToReset: pace && typeof pace.willLastToReset === "boolean" ? pace.willLastToReset : null,
    order: order
  }
}

function usageWindows(record) {
  var usage = record && record.usage ? record.usage : {}
  var windows = []
  var keys = ["primary", "secondary", "tertiary"]
  var order = 0
  for (var i = 0; i < keys.length; i++) {
    var row = normalizedWindow(record, keys[i], usage[keys[i]], order++)
    if (row) windows.push(row)
  }

  var extra = Array.isArray(usage.extraRateWindows) ? usage.extraRateWindows : []
  for (var j = 0; j < extra.length; j++) {
    var entry = extra[j] || {}
    var extraRow = normalizedWindow(record, "extra-" + j, entry.window || entry, order++)
    if (extraRow) {
      var title = nonEmpty(entry.title)
      if (title !== "") extraRow.title = title
      var id = nonEmpty(entry.id)
      if (id !== "") extraRow.id = id
      windows.push(extraRow)
    }
  }

  windows.sort(function(a, b) {
    if (b.usedPercent !== a.usedPercent) return b.usedPercent - a.usedPercent
    return a.order - b.order
  })
  return windows
}

function localDateKey(date) {
  var value = date || new Date()
  return value.getFullYear() + "-" + String(value.getMonth() + 1).padStart(2, "0")
    + "-" + String(value.getDate()).padStart(2, "0")
}

function dailyCostRow(costRecord) {
  var days = costRecord && Array.isArray(costRecord.daily) ? costRecord.daily : []
  var today = localDateKey(new Date())
  for (var i = 0; i < days.length; i++) {
    var row = days[i] || {}
    var date = nonEmpty(row.date || row.day)
    if (date !== today) continue
    return {
      label: "Today",
      costUSD: numberOrNull(row.costUSD !== undefined ? row.costUSD : (row.totalCostUSD !== undefined ? row.totalCostUSD : row.cost)),
      tokens: numberOrNull(row.tokens !== undefined ? row.tokens : row.totalTokens)
    }
  }
  return null
}

function normalizedCost(record) {
  if (!record || record.error) return null
  var today = dailyCostRow(record)
  var sessionCost = numberOrNull(record.sessionCostUSD)
  var sessionTokens = numberOrNull(record.sessionTokens)
  var summary = today || {
    label: "Session",
    costUSD: sessionCost,
    tokens: sessionTokens
  }
  return {
    summaryLabel: summary.label,
    summaryCostUSD: summary.costUSD,
    summaryTokens: summary.tokens,
    sessionCostUSD: sessionCost,
    sessionTokens: sessionTokens,
    last30DaysCostUSD: numberOrNull(record.last30DaysCostUSD),
    last30DaysTokens: numberOrNull(record.last30DaysTokens),
    updatedAt: nonEmpty(record.updatedAt)
  }
}

function costIndex(payload) {
  var result = {}
  var records = asArray(payload)
  for (var i = 0; i < records.length; i++) {
    var id = nonEmpty(records[i] && records[i].provider).toLowerCase()
    if (id !== "" && !records[i].error) result[id] = normalizedCost(records[i])
  }
  return result
}

function creditsFor(record) {
  var credits = record && record.credits ? record.credits : null
  if (!credits) return null
  var remaining = numberOrNull(credits.remaining)
  if (remaining === null) return null
  return {
    remaining: remaining,
    updatedAt: nonEmpty(credits.updatedAt)
  }
}

function normalizeProviders(usagePayload, costPayload) {
  var records = asArray(usagePayload)
  var costs = costIndex(costPayload)
  var providers = []
  var seen = {}

  for (var i = 0; i < records.length; i++) {
    var record = records[i] || {}
    var providerId = nonEmpty(record.provider).toLowerCase()
    if (providerId === "" || record.error || seen[providerId]) continue
    seen[providerId] = true

    var windows = usageWindows(record)
    var usage = record.usage || {}
    providers.push({
      providerId: providerId,
      providerName: providerName(providerId),
      source: nonEmpty(record.source),
      version: nonEmpty(record.version),
      windows: windows,
      bindingWindow: windows.length > 0 ? windows[0] : null,
      credits: creditsFor(record),
      cost: costs[providerId] || null,
      updatedAt: nonEmpty(usage.updatedAt || record.updatedAt),
      dataConfidence: nonEmpty(usage.dataConfidence)
    })
  }

  providers.sort(function(a, b) {
    var aPercent = a.bindingWindow ? a.bindingWindow.usedPercent : -1
    var bPercent = b.bindingWindow ? b.bindingWindow.usedPercent : -1
    if (bPercent !== aPercent) return bPercent - aPercent
    return a.providerName.localeCompare(b.providerName)
  })
  return providers
}

function formatPercent(value) {
  var number = numberOrNull(value)
  return number === null ? "—" : Math.round(number) + "%"
}

function formatDuration(milliseconds) {
  if (!(milliseconds > 0)) return "now"
  var minutes = Math.max(1, Math.floor(milliseconds / 60000))
  var hours = Math.floor(minutes / 60)
  var days = Math.floor(hours / 24)
  if (days > 0) return days + "d " + (hours % 24) + "h"
  if (hours > 0) return hours + "h " + (minutes % 60) + "m"
  return minutes + "m"
}

function resetLabel(window, nowMs) {
  if (!window) return "Reset unavailable"
  var resetAt = nonEmpty(window.resetsAt)
  if (resetAt !== "") {
    var timestamp = new Date(resetAt).getTime()
    if (isFinite(timestamp)) return "Resets in " + formatDuration(timestamp - nowMs)
  }
  var fallback = nonEmpty(window.resetDescription)
  return fallback === "" ? "Reset unavailable" : fallback
}

function updatedLabel(value, nowMs) {
  var text = nonEmpty(value)
  if (text === "") return "Not updated yet"
  var timestamp = new Date(text).getTime()
  if (!isFinite(timestamp)) return "Updated " + text
  var age = Math.max(0, nowMs - timestamp)
  if (age < 60000) return "Updated just now"
  if (age < 3600000) return "Updated " + Math.floor(age / 60000) + "m ago"
  if (age < 86400000) return "Updated " + Math.floor(age / 3600000) + "h ago"
  return "Updated " + Math.floor(age / 86400000) + "d ago"
}

function formatTokens(value) {
  var number = numberOrNull(value)
  if (number === null) return "—"
  var absolute = Math.abs(number)
  if (absolute >= 1000000000) return (number / 1000000000).toFixed(absolute >= 10000000000 ? 0 : 1).replace(/\.0$/, "") + "B"
  if (absolute >= 1000000) return (number / 1000000).toFixed(absolute >= 10000000 ? 0 : 1).replace(/\.0$/, "") + "M"
  if (absolute >= 1000) return (number / 1000).toFixed(absolute >= 10000 ? 0 : 1).replace(/\.0$/, "") + "K"
  return String(Math.round(number))
}

function formatMoney(value) {
  var number = numberOrNull(value)
  return number === null ? "—" : "$" + number.toFixed(2)
}

function costSummary(providers) {
  var label = ""
  var cost = 0
  var tokens = 0
  var hasCost = false
  var hasTokens = false
  for (var i = 0; i < providers.length; i++) {
    var item = providers[i].cost
    if (!item) continue
    if (label === "") label = item.summaryLabel
    if (label !== item.summaryLabel) label = "Current"
    if (item.summaryCostUSD !== null) { cost += item.summaryCostUSD; hasCost = true }
    if (item.summaryTokens !== null) { tokens += item.summaryTokens; hasTokens = true }
  }
  if (!hasCost && !hasTokens) return "Cost unavailable"
  var parts = []
  if (hasCost) parts.push(formatMoney(cost))
  if (hasTokens) parts.push(formatTokens(tokens) + " tokens")
  return (label || "Current") + " " + parts.join(" · ")
}
