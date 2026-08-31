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
  var expectedUsedPercent = clampPercent(pace && pace.expectedUsedPercent)
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
    expectedUsedPercent: expectedUsedPercent,
    expectedRemainingPercent: expectedUsedPercent === null ? null : 100 - expectedUsedPercent,
    deltaPercent: numberOrNull(pace && pace.deltaPercent),
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

function normalizedDailyCosts(costRecord) {
  var days = costRecord && Array.isArray(costRecord.daily) ? costRecord.daily : []
  var result = []
  for (var i = 0; i < days.length; i++) {
    var row = days[i] || {}
    var date = nonEmpty(row.date || row.day)
    if (date === "") continue
    var costUSD = numberOrNull(row.costUSD !== undefined
      ? row.costUSD
      : (row.totalCostUSD !== undefined ? row.totalCostUSD : (row.totalCost !== undefined ? row.totalCost : row.cost)))
    var tokens = numberOrNull(row.tokens !== undefined ? row.tokens : row.totalTokens)
    if (costUSD === null && tokens === null) continue
    result.push({
      date: date,
      label: date.length >= 10 ? date.slice(5) : date,
      costUSD: costUSD,
      tokens: tokens
    })
  }
  result.sort(function(a, b) { return a.date.localeCompare(b.date) })
  return result
}

function dailyCostRow(costRecord) {
  var days = normalizedDailyCosts(costRecord)
  var today = localDateKey(new Date())
  for (var i = 0; i < days.length; i++) {
    var row = days[i] || {}
    if (row.date !== today) continue
    return {
      label: "Today",
      costUSD: row.costUSD,
      tokens: row.tokens
    }
  }
  return null
}

function mostUsedModel(costRecord) {
  var days = costRecord && Array.isArray(costRecord.daily) ? costRecord.daily : []
  var totals = {}
  var bestName = ""
  var bestTokens = -1
  for (var i = 0; i < days.length; i++) {
    var models = Array.isArray(days[i] && days[i].modelBreakdowns) ? days[i].modelBreakdowns : []
    for (var j = 0; j < models.length; j++) {
      var name = nonEmpty(models[j] && models[j].modelName)
      var tokens = numberOrNull(models[j] && models[j].totalTokens)
      if (name === "" || tokens === null || tokens <= 0) continue
      totals[name] = (totals[name] || 0) + tokens
      if (totals[name] > bestTokens) {
        bestName = name
        bestTokens = totals[name]
      }
    }
  }
  return bestName
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
    mostUsedModel: mostUsedModel(record),
    daily: normalizedDailyCosts(record),
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

function maskedAccountLabel(value) {
  var label = nonEmpty(value)
  if (label === "") return ""

  var at = label.lastIndexOf("@")
  var local = at > 0 ? label.slice(0, at) : label
  var domain = at > 0 ? label.slice(at) : ""
  if (local.length === 1) return "•" + domain

  var visible = local.length > 4 ? 2 : 1
  return local.slice(0, visible) + "•".repeat(Math.max(2, local.length - visible)) + domain
}

function identityFor(record) {
  var usage = record && record.usage ? record.usage : {}
  var identity = usage.identity && typeof usage.identity === "object" ? usage.identity : {}
  var accountLabel = maskedAccountLabel(usage.accountEmail || identity.accountEmail || record.account)
  var plan = nonEmpty(usage.loginMethod || identity.loginMethod)
  return {
    accountLabel: accountLabel,
    planLabel: plan === "" ? "" : providerName(plan)
  }
}

function resetCreditsFor(record) {
  var usage = record && record.usage ? record.usage : {}
  var credits = usage.codexResetCredits
  if (!credits || typeof credits !== "object") return null
  var availableCount = numberOrNull(credits.availableCount)
  if (availableCount === null && Array.isArray(credits.credits)) availableCount = credits.credits.length
  if (availableCount === null) return null
  var expiresAt = ""
  var entries = Array.isArray(credits.credits) ? credits.credits : []
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i] || {}
    var status = nonEmpty(entry.status).toLowerCase()
    if (status !== "" && status !== "available") continue
    var candidate = nonEmpty(entry.expires_at || entry.expiresAt)
    if (candidate !== "" && (expiresAt === "" || candidate < expiresAt)) expiresAt = candidate
  }
  return {
    availableCount: availableCount,
    expiresAt: expiresAt,
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
    var identity = identityFor(record)
    providers.push({
      providerId: providerId,
      providerName: providerName(providerId),
      source: nonEmpty(record.source),
      version: nonEmpty(record.version),
      windows: windows,
      bindingWindow: windows.length > 0 ? windows[0] : null,
      credits: creditsFor(record),
      resetCredits: resetCreditsFor(record),
      cost: costs[providerId] || null,
      accountLabel: identity.accountLabel,
      planLabel: identity.planLabel,
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

function viewTabs(providers) {
  var items = Array.isArray(providers) ? providers : []
  var tabs = [{ viewId: "overview", label: "Overview" }]
  var codex = null
  var others = []
  var seen = {}

  for (var i = 0; i < items.length; i++) {
    var item = items[i] || {}
    var providerId = nonEmpty(item.providerId).toLowerCase()
    if (providerId === "" || seen[providerId]) continue
    seen[providerId] = true
    var tab = {
      viewId: providerId,
      label: nonEmpty(item.providerName) || providerName(providerId)
    }
    if (providerId === "codex") codex = tab
    else others.push(tab)
  }

  if (codex) tabs.push(codex)
  tabs.push({ viewId: "radar", label: "Radar" })
  return tabs.concat(others)
}

function formatPercent(value) {
  var number = numberOrNull(value)
  return number === null ? "—" : Math.round(number) + "%"
}

function quotaHealth(remainingPercent) {
  var remaining = clampPercent(remainingPercent)
  if (remaining === null) return null
  if (remaining <= 10) return 0
  return Math.min(1, (remaining - 10) / 90)
}

function resetCloseness(window, nowMs) {
  if (!window) return null
  var resetAt = nonEmpty(window.resetsAt)
  if (resetAt === "") return null
  var timestamp = new Date(resetAt).getTime()
  if (!isFinite(timestamp)) return null

  var current = numberOrNull(nowMs)
  if (current === null) current = Date.now()
  var remainingMs = Math.max(0, timestamp - current)
  var horizonMs = 7 * 24 * 60 * 60000
  return 1 - Math.min(1, remainingMs / horizonMs)
}

function resetCreditHealth(availableCount) {
  var count = numberOrNull(availableCount)
  if (count === null) return null
  return Math.max(0, Math.min(1, count / 2))
}

function expiryHealth(value, nowMs) {
  var text = nonEmpty(value)
  if (text === "") return null
  var timestamp = new Date(text).getTime()
  if (!isFinite(timestamp)) return null

  var current = numberOrNull(nowMs)
  if (current === null) current = Date.now()
  var remainingMs = Math.max(0, timestamp - current)
  var horizonMs = 30 * 24 * 60 * 60000
  return Math.min(1, remainingMs / horizonMs)
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

function expiryLabel(value, nowMs) {
  var text = nonEmpty(value)
  if (text === "") return "Expiry unavailable"
  var date = new Date(text)
  var timestamp = date.getTime()
  if (!isFinite(timestamp)) return "Expires " + text
  if (timestamp <= nowMs) return "Expired"
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var deadline = months[date.getMonth()] + " " + date.getDate()
  if (date.getFullYear() !== new Date(nowMs).getFullYear()) deadline += ", " + date.getFullYear()
  return "Expires " + deadline + " · " + formatDuration(timestamp - nowMs)
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

function last30DaysSummary(providers) {
  var cost = 0
  var tokens = 0
  var costProviderCount = 0
  var hasCost = false
  var hasTokens = false
  var rows = Array.isArray(providers) ? providers : []
  for (var i = 0; i < rows.length; i++) {
    var item = rows[i] && rows[i].cost
    if (!item) continue
    var counted = item.last30DaysCostUSD !== null || item.last30DaysTokens !== null
    if (counted) costProviderCount++
    if (item.last30DaysCostUSD !== null) { cost += item.last30DaysCostUSD; hasCost = true }
    if (item.last30DaysTokens !== null) { tokens += item.last30DaysTokens; hasTokens = true }
  }
  return {
    providerCount: rows.length,
    costProviderCount: costProviderCount,
    costUSD: hasCost ? cost : null,
    tokens: hasTokens ? tokens : null,
    hasCost: hasCost,
    hasTokens: hasTokens
  }
}

function overviewProviders(providers) {
  var rows = Array.isArray(providers) ? providers.slice() : []
  var result = []
  for (var i = 0; i < rows.length; i++)
    if (rows[i] && rows[i].providerId === "codex") result.push(rows[i])
  for (var j = 0; j < rows.length; j++)
    if (!rows[j] || rows[j].providerId !== "codex") result.push(rows[j])
  return result
}

function dailyMaximum(days) {
  // QML exposes Repeater-backed JavaScript lists as array-like values that do
  // not always satisfy Array.isArray(), so accept any finite-length sequence.
  var rows = days && typeof days.length === "number" ? days : []
  var maximum = 0
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i] || {}
    var value = row.costUSD !== null && row.costUSD !== undefined ? Number(row.costUSD) : Number(row.tokens)
    if (isFinite(value)) maximum = Math.max(maximum, value)
  }
  return maximum
}

function radarModelLabel(value) {
  var model = nonEmpty(value).toLowerCase()
  var known = {
    "gpt-5.5": "5.5",
    "gpt-5.6-sol": "Sol",
    "gpt-5.6-terra": "Terra",
    "gpt-5.6-luna": "Luna"
  }
  if (known[model]) return known[model]
  return providerName(model.replace(/^gpt-/, ""))
}

function radarCategoryTitle(key) {
  var known = {
    daily_development: "Daily development",
    "daily-development": "Daily development",
    hard_problems: "Hard problems",
    "hard-problems": "Hard problems",
    background_automation: "Background automation",
    "background-automation": "Background automation",
    lobster_tasks: "Claw tasks",
    "lobster-tasks": "Claw tasks",
    long_running_agents: "Claw tasks",
    "long-running-agents": "Claw tasks"
  }
  return known[key] || ""
}

function radarCategoryRule(key) {
  var known = {
    daily_development: "Balances measured intelligence, speed, and cost.",
    "daily-development": "Balances measured intelligence, speed, and cost.",
    hard_problems: "Prioritizes the highest measured intelligence.",
    "hard-problems": "Prioritizes the highest measured intelligence.",
    background_automation: "Meets the intelligence threshold, then favors lower cost.",
    "background-automation": "Meets the intelligence threshold, then favors lower cost.",
    lobster_tasks: "Claw tasks favor the lowest combined time and cost above the IQ threshold.",
    "lobster-tasks": "Claw tasks favor the lowest combined time and cost above the IQ threshold.",
    long_running_agents: "Claw tasks favor the lowest combined time and cost above the IQ threshold.",
    "long-running-agents": "Claw tasks favor the lowest combined time and cost above the IQ threshold."
  }
  return known[key] || ""
}

function radarIdentity(item) {
  return nonEmpty(item && item.model).toLowerCase() + "|" + nonEmpty(item && item.effort).toLowerCase()
}

function radarEligible(item) {
  var model = nonEmpty(item && item.model).toLowerCase()
  return model === "gpt-5.5" || model === "gpt-5.6-sol"
    || model === "gpt-5.6-terra" || model === "gpt-5.6-luna"
}

function radarNumber(primary, fallback) {
  var number = numberOrNull(primary)
  return number === null ? numberOrNull(fallback) : number
}

function radarItem(item, canonicalIq, metrics) {
  return {
    model: nonEmpty(item && item.model),
    effort: nonEmpty(item && item.effort),
    iq: radarNumber(canonicalIq, item && item.iq),
    average_cost_usd: numberOrNull(item && item.average_cost_usd),
    average_price_usd: radarNumber(item && item.average_price_usd, metrics && metrics.average_price_usd),
    average_duration_minutes: numberOrNull(item && item.average_duration_minutes),
    average_minutes: radarNumber(item && item.average_minutes, metrics && metrics.average_minutes),
    combined_cost_index: radarNumber(item && item.combined_cost_index, metrics && metrics.combined_cost_index)
  }
}

function supplementRadarRecommendations(body, metricsPayload) {
  var rawGroups = body.recommendations !== undefined
    ? body.recommendations
    : (body.station_recommendations !== undefined ? body.station_recommendations : body.station_recs)
  if (!Array.isArray(rawGroups)) throw new Error("unexpected response shape")

  var comprehensive = Array.isArray(body.comprehensive_points) ? body.comprehensive_points : []
  var canonicalIq = {}
  for (var i = 0; i < comprehensive.length; i++) {
    var point = comprehensive[i] || {}
    if (!radarEligible(point)) continue
    canonicalIq[radarIdentity(point)] = numberOrNull(point.iq)
  }

  var metricsBody = metricsPayload && metricsPayload.data && typeof metricsPayload.data === "object"
    ? metricsPayload.data
    : metricsPayload
  var metricRows = metricsBody && Array.isArray(metricsBody.points) ? metricsBody.points : []
  var metricsByKey = {}
  for (var j = 0; j < metricRows.length; j++) {
    var metric = metricRows[j] || {}
    metricsByKey[radarIdentity(metric)] = metric
  }

  var candidates = []
  for (var k = 0; k < comprehensive.length; k++) {
    var candidatePoint = comprehensive[k] || {}
    if (!radarEligible(candidatePoint)) continue
    var candidateKey = radarIdentity(candidatePoint)
    candidates.push(radarItem(candidatePoint, canonicalIq[candidateKey], metricsByKey[candidateKey]))
  }

  function rankedCandidates(groupKey) {
    var key = groupKey.replace(/_/g, "-")
    var eligible = candidates.filter(function(item) {
      if (item.iq === null) return false
      if (key === "daily-development") return item.iq >= 90 && item.average_minutes !== null
      if (key === "background-automation") return Math.round(item.iq) >= 80 && item.average_price_usd !== null
      if (key === "long-running-agents" || key === "lobster-tasks")
        return item.iq >= 55 && item.combined_cost_index !== null
      return true
    })
    eligible.sort(function(left, right) {
      if (key === "daily-development")
        return left.average_minutes - right.average_minutes
          || (left.combined_cost_index || 0) - (right.combined_cost_index || 0)
          || right.iq - left.iq
      if (key === "background-automation")
        return left.average_price_usd - right.average_price_usd || right.iq - left.iq
      if (key === "long-running-agents" || key === "lobster-tasks")
        return left.combined_cost_index - right.combined_cost_index || right.iq - left.iq
      return right.iq - left.iq
        || (left.combined_cost_index === null ? Number.POSITIVE_INFINITY : left.combined_cost_index)
          - (right.combined_cost_index === null ? Number.POSITIVE_INFINITY : right.combined_cost_index)
    })
    return eligible
  }

  var supplemented = []
  for (var groupIndex = 0; groupIndex < rawGroups.length; groupIndex++) {
    var group = rawGroups[groupIndex] || {}
    var groupKey = nonEmpty(group.key || group.id).toLowerCase()
    var sourceItems = Array.isArray(group.items)
      ? group.items
      : (Array.isArray(group.models) ? group.models : group.recommendations)
    if (!Array.isArray(sourceItems)) sourceItems = []
    var items = []
    var seen = {}
    for (var itemIndex = 0; itemIndex < sourceItems.length && items.length < 2; itemIndex++) {
      var sourceItem = sourceItems[itemIndex] || {}
      if (!radarEligible(sourceItem)) continue
      var sourceKey = radarIdentity(sourceItem)
      if (seen[sourceKey]) continue
      items.push(radarItem(sourceItem, canonicalIq[sourceKey], metricsByKey[sourceKey]))
      seen[sourceKey] = true
    }
    var ranked = rankedCandidates(groupKey)
    for (var candidateIndex = 0; candidateIndex < ranked.length && items.length < 2; candidateIndex++) {
      var rankedItem = ranked[candidateIndex]
      var rankedKey = radarIdentity(rankedItem)
      if (seen[rankedKey]) continue
      items.push(rankedItem)
      seen[rankedKey] = true
    }
    supplemented.push({
      key: groupKey,
      title: nonEmpty(group.title),
      rule: nonEmpty(group.rule),
      items: items
    })
  }
  return supplemented
}

function normalizeRadarInsights(payload, metricsPayload) {
  if (!payload || typeof payload !== "object") throw new Error("unexpected response shape")
  var body = payload.data && typeof payload.data === "object" ? payload.data : payload
  var rawGroups = supplementRadarRecommendations(body, metricsPayload)

  var preferredOrder = {
    daily_development: 0,
    "daily-development": 0,
    hard_problems: 1,
    "hard-problems": 1,
    background_automation: 2,
    "background-automation": 2,
    lobster_tasks: 3,
    "lobster-tasks": 3,
    long_running_agents: 3,
    "long-running-agents": 3
  }
  var groups = []
  for (var i = 0; i < rawGroups.length; i++) {
    var group = rawGroups[i] || {}
    var key = nonEmpty(group.key || group.id).toLowerCase()
    if (key === "") continue
    var rawItems = Array.isArray(group.items)
      ? group.items
      : (Array.isArray(group.models) ? group.models : group.recommendations)
    if (!Array.isArray(rawItems)) continue

    var items = []
    for (var j = 0; j < rawItems.length; j++) {
      var item = rawItems[j] || {}
      var model = nonEmpty(item.model)
      if (model === "") continue
      var modelLabel = radarModelLabel(model)
      var effort = nonEmpty(item.effort).toLowerCase()
      items.push({
        model: model,
        modelLabel: modelLabel,
        effort: effort,
        label: [modelLabel, effort].filter(function(value) { return value !== "" }).join(" "),
        iq: numberOrNull(item.iq),
        durationMinutes: radarNumber(item.average_duration_minutes, item.average_minutes),
        costUSD: radarNumber(item.average_cost_usd, item.average_price_usd)
      })
    }
    if (items.length === 0) continue
    groups.push({
      key: key,
      title: radarCategoryTitle(key) || nonEmpty(group.title) || providerName(key),
      rule: radarCategoryRule(key),
      items: items,
      order: preferredOrder[key] === undefined ? 100 + i : preferredOrder[key]
    })
  }

  groups.sort(function(a, b) { return a.order - b.order })
  for (var k = 0; k < groups.length; k++) delete groups[k].order
  return {
    generatedAt: nonEmpty(body.generated_at || body.generatedAt),
    sourceUpdatedAt: nonEmpty(body.source_updated_at || body.sourceUpdatedAt),
    groups: groups
  }
}

function hasCompleteRadarRecommendations(value) {
  var groups = value && Array.isArray(value.groups) ? value.groups : []
  var required = ["daily_development", "hard_problems", "background_automation", "lobster_tasks"]
  var byKey = {}
  for (var i = 0; i < groups.length; i++) {
    var group = groups[i] || {}
    byKey[nonEmpty(group.key)] = group
  }
  for (var j = 0; j < required.length; j++) {
    var candidate = byKey[required[j]]
    if (!candidate || !Array.isArray(candidate.items) || candidate.items.length !== 2) return false
  }
  return true
}
