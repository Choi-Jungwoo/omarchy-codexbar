import assert from "node:assert/strict"
import fs from "node:fs"
import test from "node:test"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../Model.js", import.meta.url), "utf8")
const context = { Date, Math, Number, String, Array, Object, JSON, isFinite }
vm.createContext(context)
vm.runInContext(`${source}\nglobalThis.Model = {
  normalizeProviders, formatPercent, resetLabel, formatTokens, formatMoney, costSummary,
  last30DaysSummary, overviewProviders, dailyMaximum, expiryLabel, normalizeRadarInsights,
  viewTabs, hasCompleteRadarRecommendations, quotaHealth, resetCloseness,
  resetCreditHealth, expiryHealth
}`, context)
const { Model } = context

test("only successful provider records become dynamic tabs", () => {
  const usage = [
    {
      provider: "gemini",
      usage: { primary: { usedPercent: 16, resetsAt: "2026-08-31T12:00:00Z", windowMinutes: 1440 } }
    },
    {
      provider: "codex",
      pace: { secondary: { expectedUsedPercent: 12, deltaPercent: -8, summary: "8% in reserve" } },
      usage: {
        primary: { usedPercent: 72, resetsAt: "2026-08-30T18:00:00Z", windowMinutes: 300 },
        secondary: { usedPercent: 41, resetsAt: "2026-09-02T12:00:00Z", windowMinutes: 10080 }
      }
    },
    { provider: "cursor", error: "not configured" },
    {
      provider: "claude",
      usage: { primary: { usedPercent: 58, resetsAt: "2026-08-30T20:00:00Z", windowMinutes: 300 } }
    }
  ]

  const providers = Model.normalizeProviders(usage, [])
  assert.deepEqual(Array.from(providers, provider => provider.providerId), ["codex", "claude", "gemini"])
  assert.equal(providers.some(provider => provider.providerId === "cursor"), false)
  assert.equal(providers[0].bindingWindow.title, "5-hour window")
  assert.equal(providers[0].windows[1].title, "Weekly")
  assert.equal(providers[0].windows[1].expectedUsedPercent, 12)
  assert.equal(providers[0].windows[1].expectedRemainingPercent, 88)
})

test("the most used quota, including an extra window, binds the provider", () => {
  const providers = Model.normalizeProviders([{
    provider: "new_provider",
    usage: {
      primary: { usedPercent: 20 },
      extraRateWindows: [{ id: "sonnet", title: "Sonnet", window: { usedPercent: 83 } }]
    }
  }], [])

  assert.equal(providers[0].providerName, "New Provider")
  assert.equal(providers[0].bindingWindow.id, "sonnet")
  assert.equal(providers[0].bindingWindow.title, "Sonnet")
  assert.equal(providers[0].bindingWindow.remainingPercent, 17)
})

test("Codex and Radar stay ahead of tighter non-Codex provider tabs", () => {
  const providers = Model.normalizeProviders([
    { provider: "claude", usage: { primary: { usedPercent: 90 } } },
    { provider: "codex", usage: { primary: { usedPercent: 20 } } },
    { provider: "gemini", usage: { primary: { usedPercent: 10 } } }
  ], [])

  assert.deepEqual(Array.from(providers, provider => provider.providerId), ["claude", "codex", "gemini"])
  assert.deepEqual(Array.from(Model.viewTabs(providers), tab => tab.viewId), [
    "overview", "codex", "radar", "claude", "gemini"
  ])
  assert.deepEqual(Array.from(Model.viewTabs(providers.filter(provider => provider.providerId !== "codex")), tab => tab.viewId), [
    "overview", "radar", "claude", "gemini"
  ])
})

test("cost data merges by provider without creating providers", () => {
  const providers = Model.normalizeProviders([
    { provider: "codex", usage: { primary: { usedPercent: 25 } } }
  ], [
    { provider: "codex", sessionCostUSD: 0.42, sessionTokens: 38000, last30DaysCostUSD: 12.5 },
    { provider: "claude", sessionCostUSD: 9, sessionTokens: 10 }
  ])

  assert.equal(providers.length, 1)
  assert.equal(providers[0].cost.summaryLabel, "Session")
  assert.equal(Model.costSummary(providers), "Session $0.42 · 38K tokens")
})

test("30-day totals, account identity, reset credits, and daily costs stay available to the overview", () => {
  const today = new Date()
  const todayKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`
  const providers = Model.normalizeProviders([{
    provider: "codex",
    account: "ijungwoo02@gmail.com",
    usage: {
      loginMethod: "pro",
      primary: { usedPercent: 30 },
      codexResetCredits: {
        availableCount: 2,
        credits: [
          { status: "used", expires_at: "2026-09-01T00:00:00Z" },
          { status: "available", expires_at: "2026-09-21T00:25:27Z" }
        ]
      }
    }
  }, {
    provider: "claude",
    usage: { primary: { usedPercent: 85 } }
  }], [{
    provider: "codex",
    last30DaysCostUSD: 18.7,
    last30DaysTokens: 29569201,
    daily: [{ date: todayKey, totalCost: 4.57, totalTokens: 7893450 }]
  }])

  const codex = providers.find(provider => provider.providerId === "codex")
  assert.equal(codex.accountLabel, "ij••••••••@gmail.com")
  assert.equal(codex.planLabel, "Pro")
  assert.equal(codex.resetCredits.availableCount, 2)
  assert.equal(codex.resetCredits.expiresAt, "2026-09-21T00:25:27Z")
  assert.equal(codex.cost.summaryLabel, "Today")
  assert.equal(codex.cost.summaryCostUSD, 4.57)
  assert.deepEqual(Array.from(codex.cost.daily, row => ({ date: row.date, costUSD: row.costUSD, tokens: row.tokens })), [
    { date: todayKey, costUSD: 4.57, tokens: 7893450 }
  ])

  assert.deepEqual({ ...Model.last30DaysSummary(providers) }, {
    providerCount: 2,
    costProviderCount: 1,
    costUSD: 18.7,
    tokens: 29569201,
    hasCost: true,
    hasTokens: true
  })
  assert.equal(Model.overviewProviders(providers)[0].providerId, "codex")
  assert.equal(Model.dailyMaximum(codex.cost.daily), 4.57)
  assert.equal(Model.expiryLabel("2026-09-21T00:25:27Z", new Date("2026-08-31T00:25:27Z").getTime()), "Expires Sep 21 · 21d 0h")
})

test("missing and malformed optional values stay readable", () => {
  const providers = Model.normalizeProviders([{ provider: "codex", usage: {} }], [])
  assert.equal(providers.length, 1)
  assert.equal(providers[0].bindingWindow, null)
  assert.equal(Model.formatPercent(undefined), "—")
  assert.equal(Model.formatTokens(undefined), "—")
  assert.equal(Model.formatMoney(undefined), "—")
  assert.equal(Model.resetLabel(null, Date.now()), "Reset unavailable")
})

test("quota and reset emphasis follow the live values", () => {
  assert.equal(Model.quotaHealth(10), 0)
  assert.equal(Model.quotaHealth(55), 0.5)
  assert.equal(Model.quotaHealth(100), 1)
  assert.equal(Model.quotaHealth(undefined), null)

  const now = new Date("2026-08-31T00:00:00Z").getTime()
  const weekly = { resetsAt: "2026-09-07T00:00:00Z", windowMinutes: 10080 }
  const nearlyReset = { resetsAt: "2026-08-31T01:00:00Z", windowMinutes: 10080 }
  assert.equal(Model.resetCloseness(weekly, now), 0)
  assert.ok(Model.resetCloseness(nearlyReset, now) > 0.99)
  assert.equal(Model.resetCloseness({}, now), null)

  assert.equal(Model.resetCreditHealth(0), 0)
  assert.equal(Model.resetCreditHealth(1), 0.5)
  assert.equal(Model.resetCreditHealth(2), 1)
  assert.equal(Model.resetCreditHealth(undefined), null)

  assert.equal(Model.expiryHealth("2026-08-31T00:00:00Z", now), 0)
  assert.equal(Model.expiryHealth("2026-09-15T00:00:00Z", now), 0.5)
  assert.equal(Model.expiryHealth("2026-09-30T00:00:00Z", now), 1)
  assert.equal(Model.expiryHealth("", now), null)
})

test("Codex Radar recommendations become a compact ordered ledger", () => {
  const radar = Model.normalizeRadarInsights({
    generated_at: "2026-08-30T17:55:03+00:00",
    source_updated_at: "2026-08-30T17:50:36+00:00",
    recommendations: [
      {
        key: "lobster_tasks",
        title: "跑龙虾类任务",
        rule: "IQ ≥55，按综合成本最低取 2 个。",
        items: [
          {
            model: "gpt-5.6-terra",
            effort: "low",
            iq: 59.32,
            average_cost_usd: 0.439427,
            average_duration_minutes: 8.28
          },
          { model: "", effort: "medium", iq: 66 }
        ]
      },
      {
        key: "daily_development",
        title: "日常开发",
        items: [{
          model: "gpt-5.5",
          effort: "high",
          iq: 93.53,
          average_price_usd: 3.332266,
          average_duration_minutes: 16.97
        }]
      }
    ]
  })

  assert.equal(radar.generatedAt, "2026-08-30T17:55:03+00:00")
  assert.equal(radar.sourceUpdatedAt, "2026-08-30T17:50:36+00:00")
  assert.deepEqual(Array.from(radar.groups, group => group.key), ["daily_development", "lobster_tasks"])
  assert.equal(radar.groups[0].title, "Daily development")
  assert.equal(radar.groups[1].title, "Claw tasks")
  assert.equal(radar.groups[1].rule, "Claw tasks favor the lowest combined time and cost above the IQ threshold.")
  assert.deepEqual({ ...radar.groups[0].items[0] }, {
    model: "gpt-5.5",
    modelLabel: "5.5",
    effort: "high",
    label: "5.5 high",
    iq: 93.53,
    durationMinutes: 16.97,
    costUSD: 3.332266
  })
  assert.equal(radar.groups[1].items.length, 1)
  assert.equal(radar.groups[1].items[0].label, "Terra low")
})

test("malformed Codex Radar payloads fail before replacing cached data", () => {
  assert.throws(() => Model.normalizeRadarInsights(null), /unexpected response shape/)
  assert.throws(() => Model.normalizeRadarInsights({ recommendations: "not-an-array" }), /unexpected response shape/)
})

test("Codex Radar efficiency metrics supplement every category to two picks", () => {
  const payload = {
    recommendations: [
      { key: "daily_development", items: [{ model: "gpt-5.5", effort: "high", iq: 94 }] },
      { key: "hard_problems", items: [{ model: "gpt-5.6-sol", effort: "ultra", iq: 103 }] },
      { key: "background_automation", items: [{ model: "gpt-5.6-luna", effort: "high", iq: 81 }] },
      { key: "lobster_tasks", items: [{ model: "gpt-5.6-terra", effort: "low", iq: 59 }] }
    ],
    comprehensive_points: [
      { model: "gpt-5.5", effort: "high", iq: 94 },
      { model: "gpt-5.6-sol", effort: "medium", iq: 92 },
      { model: "gpt-5.6-sol", effort: "ultra", iq: 103 },
      { model: "gpt-5.6-sol", effort: "max", iq: 102 },
      { model: "gpt-5.6-luna", effort: "high", iq: 81 },
      { model: "gpt-5.6-luna", effort: "xhigh", iq: 88 },
      { model: "gpt-5.6-terra", effort: "low", iq: 59 },
      { model: "gpt-5.6-terra", effort: "medium", iq: 66 }
    ]
  }
  const metrics = {
    points: [
      { model: "gpt-5.5", effort: "high", average_price_usd: 3.33, average_minutes: 17, combined_cost_index: 1700 },
      { model: "gpt-5.6-sol", effort: "medium", average_price_usd: 2.99, average_minutes: 16, combined_cost_index: 1300 },
      { model: "gpt-5.6-sol", effort: "ultra", average_price_usd: 19.42, average_minutes: 39, combined_cost_index: 370000 },
      { model: "gpt-5.6-sol", effort: "max", average_price_usd: 8.18, average_minutes: 34, combined_cost_index: 33000 },
      { model: "gpt-5.6-luna", effort: "high", average_price_usd: 0.20, average_minutes: 24, combined_cost_index: 120 },
      { model: "gpt-5.6-luna", effort: "xhigh", average_price_usd: 0.32, average_minutes: 24, combined_cost_index: 450 },
      { model: "gpt-5.6-terra", effort: "low", average_price_usd: 0.44, average_minutes: 8, combined_cost_index: 25 },
      { model: "gpt-5.6-terra", effort: "medium", average_price_usd: 0.56, average_minutes: 10, combined_cost_index: 50 }
    ]
  }

  const radar = Model.normalizeRadarInsights(payload, metrics)
  assert.deepEqual(Array.from(radar.groups, group => Array.from(group.items, item => item.label)), [
    ["5.5 high", "Sol medium"],
    ["Sol ultra", "Sol max"],
    ["Luna high", "Luna xhigh"],
    ["Terra low", "Terra medium"]
  ])
  assert.equal(radar.groups.every(group => group.items.length === 2), true)
  assert.equal(Model.hasCompleteRadarRecommendations(radar), true)
  assert.equal(Model.hasCompleteRadarRecommendations(Model.normalizeRadarInsights(payload)), false)
})
