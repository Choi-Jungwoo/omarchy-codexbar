import assert from "node:assert/strict"
import fs from "node:fs"
import test from "node:test"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../Model.js", import.meta.url), "utf8")
const context = { Date, Math, Number, String, Array, Object, JSON, isFinite }
vm.createContext(context)
vm.runInContext(`${source}\nglobalThis.Model = {
  normalizeProviders, formatPercent, resetLabel, formatTokens, formatMoney, costSummary
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

test("missing and malformed optional values stay readable", () => {
  const providers = Model.normalizeProviders([{ provider: "codex", usage: {} }], [])
  assert.equal(providers.length, 1)
  assert.equal(providers[0].bindingWindow, null)
  assert.equal(Model.formatPercent(undefined), "—")
  assert.equal(Model.formatTokens(undefined), "—")
  assert.equal(Model.formatMoney(undefined), "—")
  assert.equal(Model.resetLabel(null, Date.now()), "Reset unavailable")
})
