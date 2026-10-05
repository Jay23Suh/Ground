import { useState } from 'react'
import { ReactComponent as LegoIcon } from '../lego.svg'
import { CATEGORY_COLORS, formatHour, snippet, wordCount } from '../lib/stats'

function buildBuckets(entries, period) {
  const now = new Date()
  const buckets = []
  const sameDay = (a, b) => a.toDateString() === b.toDateString()

  if (period === 'day') {
    for (let h = 0; h < 24; h++) {
      const label = h % 6 === 0 ? formatHour(h) : ''
      buckets.push({ label, hour: h })
    }
  } else if (period === 'week') {
    // Sun–Sat of the current week, matching the abstract's calendar week
    const sunday = new Date(now)
    sunday.setDate(now.getDate() - now.getDay())
    sunday.setHours(0, 0, 0, 0)
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    for (let i = 0; i < 7; i++) {
      const start = new Date(sunday); start.setDate(sunday.getDate() + i)
      const end = new Date(start); end.setDate(start.getDate() + 1)
      buckets.push({ label: days[i], start, end })
    }
  } else if (period === 'month') {
    const y = now.getFullYear(), m = now.getMonth()
    const lastDay = new Date(y, m + 1, 0)
    const weekStart = new Date(y, m, 1)
    let weekNum = 1
    while (weekStart <= lastDay) {
      const weekEnd = new Date(weekStart); weekEnd.setDate(weekStart.getDate() + 7)
      buckets.push({ label: `Wk ${weekNum}`, start: new Date(weekStart), end: weekEnd })
      weekStart.setDate(weekStart.getDate() + 7)
      weekNum++
    }
  } else {
    const y = now.getFullYear()
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    for (let m = 0; m < 12; m++) buckets.push({ label: months[m], start: new Date(y, m, 1), end: new Date(y, m + 1, 1) })
  }

  return buckets.map(b => ({
    ...b,
    count: entries.filter(e => {
      const d = new Date(e.created_at)
      if (period === 'day') return sameDay(d, now) && d.getHours() === b.hour
      return d >= b.start && d < b.end
    }).length,
  }))
}

function EntryChart({ entries }) {
  const [period, setPeriod] = useState('week')
  const answered = entries.filter(e => !e.skipped)
  const buckets = buildBuckets(answered, period)
  const maxCount = Math.max(...buckets.map(b => b.count), 1)

  const W = 600, H = 170, padL = 28, padB = 28, padR = 12, padT = 22
  const chartW = W - padL - padR
  const chartH = H - padT - padB
  const gap = chartW / buckets.length
  const barW = Math.max(4, gap * 0.6)
  const rawTicks = maxCount <= 4
    ? Array.from({ length: maxCount + 1 }, (_, i) => i)
    : [0, Math.round(maxCount / 4), Math.round(maxCount / 2), Math.round(3 * maxCount / 4), maxCount]
  const yTicks = [...new Set(rawTicks)]

  return (
    <div className="section-card">
      <div className="chart-header">
        <span className="section-card-title" style={{ marginBottom: 0 }}>entries over time</span>
        <div className="chart-toggles">
          {['day', 'week', 'month', 'year'].map(p => (
            <button key={p} className={`chart-pill${period === p ? ' active' : ''}`} onClick={() => setPeriod(p)}>{p}</button>
          ))}
        </div>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', height: 'auto', display: 'block' }} role="img" aria-label={`entries per ${period}`}>
        {yTicks.map(t => {
          const y = padT + chartH - (t / maxCount) * chartH
          return (
            <g key={t}>
              <line x1={padL} x2={W - padR} y1={y} y2={y} className="chart-gridline" strokeWidth="1" />
              <text x={padL - 6} y={y + 4} textAnchor="end" fontSize="9" className="chart-label" fontFamily="Space Mono, monospace">{t}</text>
            </g>
          )
        })}
        {buckets.map((b, i) => {
          const barH = (b.count / maxCount) * chartH
          const x = padL + i * gap + gap / 2 - barW / 2
          return (
            <g key={i}>
              <rect x={x} y={padT + chartH - barH} width={barW} height={Math.max(barH, b.count > 0 ? 2 : 0)}
                rx="3" fill="var(--lavender)" opacity="0.85">
                <title>{`${b.label || formatHour(b.hour)}: ${b.count}`}</title>
              </rect>
              {b.label && (
                <text x={padL + i * gap + gap / 2} y={H - 4} textAnchor="middle" fontSize="9" className="chart-label" fontFamily="Space Mono, monospace">{b.label}</text>
              )}
            </g>
          )
        })}
      </svg>
    </div>
  )
}

function CategoryBreakdown({ breakdown }) {
  return (
    <div className="section-card">
      <div className="section-card-title">by category</div>
      <div className="cat-list">
        {breakdown.map(({ key, label, pct }) => (
          <div className="cat-row" key={key}>
            <span className="cat-label">{label}</span>
            <div className="cat-bar-bg">
              <div className="cat-bar-fill" style={{ width: `${pct * 100}%`, background: CATEGORY_COLORS[key] || 'var(--lavender)' }} />
            </div>
            <span className="cat-pct">{Math.round(pct * 100)}%</span>
          </div>
        ))}
      </div>
    </div>
  )
}

// Bars colored by the time of day they fall in.
function timeColor(h) {
  if (h >= 5 && h < 9) return CATEGORY_COLORS.grounding
  if (h >= 9 && h < 13) return CATEGORY_COLORS.values
  if (h >= 13 && h < 18) return CATEGORY_COLORS.emotions
  if (h >= 18 && h < 22) return CATEGORY_COLORS.gratitude
  return CATEGORY_COLORS.compassion
}

function HourPattern({ hourDist }) {
  const maxCount = Math.max(...hourDist, 1)
  return (
    <div className="section-card">
      <div className="section-card-title">when you write</div>
      <div className="hour-bars">
        {hourDist.map((count, h) => (
          <div className="hour-bar-col" key={h} title={`${formatHour(h)}: ${count}`}>
            <div className="hour-bar" style={{
              height: `${Math.max(2, (count / maxCount) * 48)}px`,
              background: count > 0 ? timeColor(h) : 'var(--card-border)',
              opacity: count > 0 ? 0.8 : 0.3,
            }} />
            <div className="hour-label">{h % 6 === 0 ? (h === 0 ? '12a' : h === 12 ? '12p' : `${h < 12 ? h : h - 12}${h < 12 ? 'a' : 'p'}`) : ' '}</div>
          </div>
        ))}
      </div>
    </div>
  )
}

function TopEntries({ title, items, onSelect }) {
  return (
    <div className="section-card">
      <div className="section-card-title">{title}</div>
      <div className="top-list">
        {items.map((item, i) => (
          <button className="top-row" key={item.id} onClick={() => onSelect(item.id)}>
            <span className="top-rank">{i + 1}</span>
            <span className="top-body">
              <span className="top-snippet">{item.snippet}</span>
              <span className="top-metric">{item.metric}</span>
            </span>
            <span className="top-chevron">›</span>
          </button>
        ))}
      </div>
    </div>
  )
}

function Card({ value, label, accent }) {
  return (
    <div className={`stats-card${accent ? ' stats-card--accent' : ''}`}>
      <div className={`stats-num${accent ? '' : ' stats-num--sm'}`}>{value}</div>
      <div className="stats-label">{label}</div>
    </div>
  )
}

export default function StatsView({ entries, stats, notes, onSelectEntry }) {
  const topLongest = entries
    .filter(e => !e.skipped)
    .map(e => ({ e, words: wordCount(e.answer) }))
    .sort((a, b) => b.words - a.words)
    .slice(0, 3)
    .map(({ e, words }) => ({ id: e.id, snippet: snippet(e.answer), metric: `${words} words` }))
    .filter(i => i.snippet)

  const notesWords = notes.reduce((s, n) => s + wordCount(n.content), 0)

  return (
    <div className="page">
      <h1 className="page-title">stats</h1>

      {stats.skipRate > 0.5 && stats.totalPrompts > 3 && (
        <div className="nudge-card">
          <LegoIcon style={{ width: 16, height: 16, flexShrink: 0 }} />
          you've been skipping a lot lately — make some time for yourself to ground
        </div>
      )}

      <h2 className="section-label">entries</h2>
      <div className="stats-grid stats-grid--3">
        <Card accent value={stats.totalEntries} label="entries" />
        <Card accent value={stats.totalWords} label="words written" />
        <Card accent value={stats.totalSkips} label="skipped" />
      </div>
      <div className="stats-grid stats-grid--4">
        <Card value={stats.avgWords || '—'} label="avg words/entry" />
        <Card value={stats.currentStreak > 0 ? `${stats.currentStreak}d` : '—'} label="current streak" />
        <Card value={stats.longestStreak > 0 ? `${stats.longestStreak}d` : '—'} label="longest streak" />
        <Card value={stats.totalPrompts ? `${Math.round(stats.skipRate * 100)}%` : '—'} label="skip rate" />
      </div>
      <div className="stats-grid stats-grid--3">
        <Card value={`${Math.round(stats.consistency * 100)}%`} label={`${stats.consistencyWindow}d consistency`} />
        <Card value={stats.mostActiveDay || '—'} label="most active day" />
        <Card value={stats.mostActiveHour != null ? formatHour(stats.mostActiveHour) : '—'} label="peak hour" />
      </div>

      {stats.categoryBreakdown.length > 0 && <CategoryBreakdown breakdown={stats.categoryBreakdown} />}
      {topLongest.length >= 2 && <TopEntries title="top 3 longest entries" items={topLongest} onSelect={onSelectEntry} />}
      <HourPattern hourDist={stats.hourDist} />
      <EntryChart entries={entries} />

      {notes.length > 0 && (
        <>
          <h2 className="section-label" style={{ marginTop: 32 }}>memories</h2>
          <div className="stats-grid stats-grid--3">
            <Card value={notes.length} label="notes" />
            <Card value={notesWords} label="words written" />
            <Card value={Math.floor(notesWords / notes.length)} label="avg words/note" />
          </div>
        </>
      )}
    </div>
  )
}
