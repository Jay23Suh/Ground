// Mirrors GroundStats in Ground/Ground/StatsView.swift (minus mood, which relies
// on Apple's on-device sentiment model).
import { CATEGORY_LABELS } from './questions'

export const CATEGORY_COLORS = {
  gratitude:  '#FFA6C9',
  compassion: '#C39BD3',
  values:     '#76D7C4',
  emotions:   '#F7971D',
  grounding:  '#005499',
  horizon:    '#60d4e8',
  community:  '#5edb97',
}

export const categoryLabel = c => CATEGORY_LABELS[c] || c || ''

export const wordCount = text => (text || '').trim().split(/\s+/).filter(Boolean).length

const startOfDay = d => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
const dayDiff = (a, b) => Math.round((startOfDay(b) - startOfDay(a)) / 86400000)

export function formatHour(h) {
  if (h === 0) return '12am'
  if (h === 12) return '12pm'
  return h < 12 ? `${h}am` : `${h - 12}pm`
}

export const formatEntryDate = iso =>
  new Date(iso).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })

// First sentence long enough to stand alone, or a truncated prefix.
export function snippet(text) {
  const cleaned = (text || '').replace(/\s+/g, ' ').trim()
  if (cleaned.length <= 15) return null
  const re = /[.!?]/g
  let m
  while ((m = re.exec(cleaned))) {
    const sentence = cleaned.slice(0, m.index + 1)
    if (sentence.length > 15) return sentence
  }
  return cleaned.length > 120 ? cleaned.slice(0, 120) + '…' : cleaned
}

export function currentStreak(answered) {
  const days = [...new Set(answered.map(e => startOfDay(e.created_at).getTime()))].sort((a, b) => b - a)
  const today = startOfDay(new Date())
  let streak = 0
  for (let i = 0; i < days.length; i++) {
    if (i === 0) {
      // Writing yesterday keeps the streak alive until today ends.
      if (dayDiff(days[0], today) > 1) break
      streak = 1
    } else {
      if (dayDiff(days[i], days[i - 1]) !== 1) break
      streak++
    }
  }
  return streak
}

export function computeStats(entries) {
  const answered = entries.filter(e => !e.skipped)
  const totalEntries = answered.length
  const totalSkips = entries.length - totalEntries
  const totalPrompts = entries.length
  const totalWords = answered.reduce((s, e) => s + wordCount(e.answer), 0)
  const avgWords = totalEntries ? Math.floor(totalWords / totalEntries) : 0
  const skipRate = totalPrompts ? totalSkips / totalPrompts : 0

  const days = [...new Set(answered.map(e => startOfDay(e.created_at).getTime()))].sort((a, b) => a - b)
  let longestStreak = 0, run = 0
  days.forEach((d, i) => {
    run = i > 0 && dayDiff(days[i - 1], d) === 1 ? run + 1 : 1
    longestStreak = Math.max(longestStreak, run)
  })

  // Consistency: denominator is days since first entry, capped at 30.
  let consistency = 0, consistencyWindow = 0
  if (days.length) {
    const today = startOfDay(new Date())
    consistencyWindow = Math.min(Math.max(1, dayDiff(days[0], today) + 1), 30)
    const active = new Set(days)
    let hits = 0
    for (let i = 0; i < consistencyWindow; i++) {
      const d = new Date(today); d.setDate(today.getDate() - i)
      if (active.has(d.getTime())) hits++
    }
    consistency = hits / consistencyWindow
  }

  const dayCounts = Array(7).fill(0)
  const hourDist = Array(24).fill(0)
  const catCounts = {}
  answered.forEach(e => {
    const d = new Date(e.created_at)
    dayCounts[d.getDay()]++
    hourDist[d.getHours()]++
    if (e.category) catCounts[e.category] = (catCounts[e.category] || 0) + 1
  })
  const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  const maxDay = Math.max(...dayCounts)
  const maxHour = Math.max(...hourDist)

  const catTotal = Object.values(catCounts).reduce((a, b) => a + b, 0)
  const categoryBreakdown = Object.entries(catCounts)
    .sort((a, b) => b[1] - a[1])
    .map(([key, count]) => ({ key, label: categoryLabel(key), count, pct: catTotal ? count / catTotal : 0 }))

  return {
    totalEntries, totalSkips, totalPrompts, totalWords, avgWords, skipRate,
    longestStreak, currentStreak: currentStreak(answered),
    consistency, consistencyWindow,
    mostActiveDay: maxDay > 0 ? weekdays[dayCounts.indexOf(maxDay)] : null,
    mostActiveHour: maxHour > 0 ? hourDist.indexOf(maxHour) : null,
    hourDist,
    topCategory: categoryBreakdown[0]?.key ?? null,
    categoryBreakdown,
  }
}

// ── Ground calendar week (Sunday–Saturday) ───────────────────────────────────
export function startOfGroundWeek(ref = new Date()) {
  const d = startOfDay(ref)
  d.setDate(d.getDate() - d.getDay())
  return d
}

export function inGroundWeek(entries, offsetWeeks, ref = new Date()) {
  const start = startOfGroundWeek(ref)
  start.setDate(start.getDate() + offsetWeeks * 7)
  const end = new Date(start); end.setDate(start.getDate() + 7)
  return entries.filter(e => { const d = new Date(e.created_at); return d >= start && d < end })
}

// Abstract unlocks after 10 answered entries spanning at least 7 days.
export function abstractUnlock(answered) {
  const oldest = answered.length ? new Date(answered[answered.length - 1].created_at) : null
  const daysIn = oldest ? Math.floor((Date.now() - oldest.getTime()) / 86400000) : 0
  const daysLeft = Math.max(0, 7 - daysIn)
  const entriesLeft = Math.max(0, 10 - answered.length)
  return { unlocked: daysLeft === 0 && entriesLeft === 0, daysLeft, entriesLeft }
}
