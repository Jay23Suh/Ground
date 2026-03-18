import { useState, useEffect, useCallback } from 'react'
import { supabase } from './supabase'

// ── Count-up animation ────────────────────────────────────────────────────────
function useCountUp(target, active, duration = 1400) {
  const [value, setValue] = useState(0)
  useEffect(() => {
    if (!active) return
    setValue(0)
    if (target === 0) return
    const start = performance.now()
    const tick = (now) => {
      const t = Math.min((now - start) / duration, 1)
      const eased = 1 - Math.pow(1 - t, 3)
      setValue(Math.round(eased * target))
      if (t < 1) requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)
  }, [target, active])
  return value
}

// ── Stats ─────────────────────────────────────────────────────────────────────
const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

function formatHour(hour) {
  if (hour === 0) return 'midnight'
  if (hour === 12) return 'noon'
  return hour < 12 ? `${hour}am` : `${hour - 12}pm`
}

function computeStats(entries) {
  const answered = entries.filter(e => e.answer && e.answer.trim().length > 0)
  const totalWords = answered.reduce((sum, e) => sum + e.answer.trim().split(/\s+/).filter(Boolean).length, 0)

  const dayCounts = {}
  answered.forEach(e => {
    const day = new Date(e.created_at).getDay()
    dayCounts[day] = (dayCounts[day] ?? 0) + 1
  })
  const topDay = Object.entries(dayCounts).sort((a, b) => b[1] - a[1])[0]
  const mostActiveDay = topDay ? DAYS[parseInt(topDay[0])] : null

  const hourCounts = {}
  answered.forEach(e => {
    const hour = new Date(e.created_at).getHours()
    hourCounts[hour] = (hourCounts[hour] ?? 0) + 1
  })
  const topHour = Object.entries(hourCounts).sort((a, b) => b[1] - a[1])[0]
  const mostActiveHour = topHour ? parseInt(topHour[0]) : null

  // Streak within the 7 days
  const entryDates = [...new Set(answered.map(e => e.created_at.split('T')[0]))].sort()
  let longestStreak = entryDates.length > 0 ? 1 : 0
  let currentStreak = entryDates.length > 0 ? 1 : 0
  for (let i = 1; i < entryDates.length; i++) {
    const prev = new Date(entryDates[i - 1]).getTime()
    const curr = new Date(entryDates[i]).getTime()
    const diffDays = (curr - prev) / (1000 * 60 * 60 * 24)
    currentStreak = diffDays === 1 ? currentStreak + 1 : 1
    longestStreak = Math.max(longestStreak, currentStreak)
  }

  const categoryCounts = {}
  answered.forEach(e => {
    if (e.category) categoryCounts[e.category] = (categoryCounts[e.category] ?? 0) + 1
  })
  const topCategoryEntry = Object.entries(categoryCounts).sort((a, b) => b[1] - a[1])[0]
  const topCategory = topCategoryEntry ? topCategoryEntry[0] : null

  const totalSkips = entries.filter(e => e.skipped).length
  const totalAll = entries.length
  const skipRate = totalAll > 0 ? Math.round((totalSkips / totalAll) * 100) : 0

  return {
    totalEntries: answered.length,
    totalWords,
    avgWordsPerEntry: answered.length > 0 ? Math.round(totalWords / answered.length) : 0,
    longestStreak,
    mostActiveDay,
    mostActiveHour,
    topCategory,
    totalSkips,
    skipRate,
  }
}

// ── Shared styles ─────────────────────────────────────────────────────────────
const slide = (bg, visible) => ({
  position: 'absolute',
  inset: 0,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  background: bg,
  opacity: visible ? 1 : 0,
  transform: visible ? 'translateY(0px)' : 'translateY(32px)',
  transition: 'opacity 0.55s ease, transform 0.55s ease',
  pointerEvents: visible ? 'auto' : 'none',
  padding: '40px 60px',
  textAlign: 'center',
  userSelect: 'none',
})

const eyebrow = (accent) => ({
  color: accent + '88',
  fontSize: 12,
  letterSpacing: 5,
  textTransform: 'uppercase',
  marginBottom: 20,
  fontFamily: 'Helvetica, sans-serif',
})

const bigNum = (accent) => ({
  color: accent,
  fontSize: 128,
  fontFamily: 'Georgia, serif',
  fontWeight: 'bold',
  lineHeight: 1,
  marginBottom: 28,
})

const caption = {
  color: '#ffffff88',
  fontSize: 20,
  fontFamily: 'Georgia, serif',
  fontStyle: 'italic',
  maxWidth: 480,
}

// ── Slide components ──────────────────────────────────────────────────────────
function TitleSlide({ visible }) {
  return (
    <div style={slide('#110d07', visible)}>
      <p style={{ color: '#f0c06066', fontSize: 12, letterSpacing: 5, textTransform: 'uppercase', marginBottom: 28, fontFamily: 'Helvetica, sans-serif' }}>
        your week in journaling
      </p>
      <h1 style={{ color: '#f0c060', fontSize: 80, fontFamily: 'Georgia, serif', fontWeight: 'bold', lineHeight: 1.1 }}>
        Abstract ✦
      </h1>
      <p style={{ color: '#ffffff44', fontSize: 13, marginTop: 48, letterSpacing: 3, fontFamily: 'Helvetica, sans-serif' }}>
        tap or press → to begin
      </p>
    </div>
  )
}

function CountSlide({ visible, bg, accent, value, label, context }) {
  const count = useCountUp(value, visible)
  return (
    <div style={slide(bg, visible)}>
      <p style={eyebrow(accent)}>{label}</p>
      <p style={bigNum(accent)}>{count.toLocaleString()}</p>
      <p style={caption}>{context}</p>
    </div>
  )
}

function TextSlide({ visible, bg, accent, headline, subtext }) {
  return (
    <div style={slide(bg, visible)}>
      <p style={{ color: accent, fontSize: 52, fontFamily: 'Georgia, serif', fontWeight: 'bold', lineHeight: 1.25, marginBottom: 28, maxWidth: 540 }}>
        {headline}
      </p>
      <p style={caption}>{subtext}</p>
    </div>
  )
}

function ClosingSlide({ visible, onClose }) {
  return (
    <div style={slide('#110d07', visible)}>
      <p style={{ color: '#f0c06055', fontSize: 12, letterSpacing: 5, textTransform: 'uppercase', marginBottom: 28, fontFamily: 'Helvetica, sans-serif' }}>
        until next time
      </p>
      <h2 style={{ color: '#f0c060', fontSize: 56, fontFamily: 'Georgia, serif', fontWeight: 'bold', lineHeight: 1.3, maxWidth: 480 }}>
        keep showing up<br />for yourself ✦
      </h2>
      {visible && (
        <button
          onClick={e => { e.stopPropagation(); onClose() }}
          style={{ marginTop: 48, background: 'transparent', border: '1px solid #f0c06044', color: '#f0c06088', fontFamily: 'Helvetica, sans-serif', fontSize: 13, letterSpacing: 3, padding: '12px 28px', borderRadius: 40, cursor: 'pointer', textTransform: 'uppercase' }}
        >
          back to journal
        </button>
      )}
    </div>
  )
}

function Dots({ total, current }) {
  return (
    <div style={{ position: 'fixed', bottom: 32, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 8, zIndex: 10, pointerEvents: 'none' }}>
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} style={{
          width: i === current ? 20 : 6, height: 6, borderRadius: 3,
          background: i === current ? '#f0c060' : '#ffffff33',
          transition: 'all 0.35s ease',
        }} />
      ))}
    </div>
  )
}

// ── Build slides ──────────────────────────────────────────────────────────────
function buildSlides(entries) {
  const stats = computeStats(entries)
  const defs = [{ type: 'title' }]

  defs.push({ type: 'count', bg: '#1e0e05', accent: '#ff8c42', value: stats.totalEntries, label: 'entries this week', context: stats.totalEntries === 1 ? 'you showed up.' : 'you kept showing up.' })
  defs.push({ type: 'count', bg: '#071a0f', accent: '#5edb97', value: stats.totalWords, label: 'words written', context: 'every one of them mattered.' })

  if (stats.avgWordsPerEntry > 0) {
    defs.push({ type: 'count', bg: '#0f0a1e', accent: '#b088ff', value: stats.avgWordsPerEntry, label: 'words on average', context: 'per entry — just enough to be honest.' })
  }

  if (stats.mostActiveDay) {
    defs.push({
      type: 'text', bg: '#071618', accent: '#60d4e8',
      headline: `you wrote most on ${stats.mostActiveDay}s`,
      subtext: stats.mostActiveHour !== null ? `usually around ${formatHour(stats.mostActiveHour)}` : 'whenever the moment felt right.',
    })
  }

  if (stats.longestStreak > 1) {
    defs.push({ type: 'count', bg: '#181205', accent: '#ffc840', value: stats.longestStreak, label: 'day streak this week', context: 'consistency is a form of care.' })
  }

  const CATEGORY_LABELS = {
    gratitude:   'Gratitude',
    compassion:  'Self-Compassion',
    values:      'Values & Meaning',
    emotions:    'Emotions',
    grounding:   'Present Moment',
  }
  const CATEGORY_SUBTEXTS = {
    gratitude:   'you kept returning to what you already have.',
    compassion:  'you were learning to be kinder to yourself.',
    values:      'you were asking what actually matters.',
    emotions:    'you were letting yourself feel it.',
    grounding:   'you were finding your way back to now.',
  }
  if (stats.topCategory) {
    defs.push({
      type: 'text', bg: '#0d0a1a', accent: '#C39BD3',
      headline: CATEGORY_LABELS[stats.topCategory] || stats.topCategory,
      subtext: CATEGORY_SUBTEXTS[stats.topCategory] || 'the theme you kept coming back to.',
    })
  }

  if (stats.totalSkips > 0) {
    const skipMsg = stats.skipRate >= 50
      ? 'it\'s okay — but make some time for yourself to reflect.'
      : 'you showed up most of the time. that matters.'
    defs.push({
      type: 'text', bg: '#100a18', accent: '#FFA6C9',
      headline: `${stats.totalSkips} skipped this week`,
      subtext: skipMsg,
    })
  }

  defs.push({ type: 'closing' })
  return defs
}

// ── Main Wrapped component ────────────────────────────────────────────────────
export default function Wrapped({ session, onClose }) {
  const [entries, setEntries] = useState(null)
  const [slides, setSlides] = useState([])
  const [current, setCurrent] = useState(0)

  useEffect(() => {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString()
    supabase
      .from('journal_entries')
      .select('*')
      .eq('user_id', session.user.id)
      .gte('created_at', sevenDaysAgo)
      .order('created_at', { ascending: true })
      .then(({ data }) => {
        const e = data ?? []
        setEntries(e)
        setSlides(buildSlides(e))
      })
  }, [session.user.id])

  const advance = useCallback(() => setCurrent(c => Math.min(c + 1, slides.length - 1)), [slides.length])

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'ArrowRight' || e.key === ' ') advance()
      if (e.key === 'ArrowLeft') setCurrent(c => Math.max(c - 1, 0))
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [advance, onClose])

  if (entries === null) {
    return (
      <div style={{ position: 'fixed', inset: 0, background: '#110d07', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200 }}>
        <p style={{ color: '#f0c06044', fontFamily: 'Georgia, serif', fontSize: 18 }}>loading...</p>
      </div>
    )
  }

  if (entries.length === 0) {
    return (
      <div style={{ position: 'fixed', inset: 0, background: '#110d07', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', zIndex: 200 }}>
        <p style={{ color: '#f0c060', fontFamily: 'Georgia, serif', fontSize: 40, fontWeight: 'bold' }}>no entries this week ✦</p>
        <p style={{ color: '#ffffff44', fontFamily: 'Georgia, serif', fontSize: 16, marginTop: 16, fontStyle: 'italic' }}>start journaling and come back.</p>
        <button onClick={onClose} style={{ marginTop: 40, background: 'transparent', border: '1px solid #f0c06044', color: '#f0c06088', fontFamily: 'Helvetica, sans-serif', fontSize: 13, letterSpacing: 3, padding: '12px 28px', borderRadius: 40, cursor: 'pointer', textTransform: 'uppercase' }}>
          back to journal
        </button>
      </div>
    )
  }

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 200, cursor: 'pointer' }} onClick={advance}>
      {slides.map((def, i) => {
        const visible = i === current
        switch (def.type) {
          case 'title':   return <TitleSlide key={i} visible={visible} />
          case 'closing': return <ClosingSlide key={i} visible={visible} onClose={onClose} />
          case 'count':   return <CountSlide key={i} visible={visible} {...def} />
          case 'text':    return <TextSlide key={i} visible={visible} {...def} />
          default:        return null
        }
      })}
      <Dots total={slides.length} current={current} />
    </div>
  )
}
