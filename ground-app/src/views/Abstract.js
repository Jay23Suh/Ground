// Weekly abstract — mirrors Ground/Ground/AbstractView.swift (minus the mood
// slides, which rely on Apple's on-device sentiment model).
import { useCallback, useEffect, useMemo, useState } from 'react'
import { abstractUnlock, computeStats, currentStreak, formatHour, inGroundWeek, snippet, wordCount } from '../lib/stats'

const DAY_NAMES = { Sun: 'Sunday', Mon: 'Monday', Tue: 'Tuesday', Wed: 'Wednesday', Thu: 'Thursday', Fri: 'Friday', Sat: 'Saturday' }

const CATEGORY_LABELS = {
  gratitude: 'Gratitude', compassion: 'Self-Compassion', values: 'Values & Meaning',
  emotions: 'Emotions', grounding: 'Present Moment', horizon: 'Growth & Goals', community: 'Connection',
}
const CATEGORY_SUBTEXTS = {
  gratitude: 'you kept returning to what you already have.',
  compassion: 'you were learning to be kinder to yourself.',
  values: 'you were asking what actually matters.',
  emotions: 'you were letting yourself feel it.',
  grounding: 'you were finding your way back to now.',
  horizon: 'you kept looking forward.',
  community: 'you were reaching out.',
}

const STOP_WORDS = new Set(`i me my myself we our ours ourselves you your yours yourself he him his himself she her hers herself
it its itself they them their theirs themselves what which who whom this that these those am is are was were be been being
have has had having do does did doing will would could should shall may might must can need dare used ought get got gets getting
gotten feel felt feels feeling think thought thinks thinking know knew knows knowing want wanted wants wanting make made makes
making see saw seen seeing come came comes coming go went gone going goes take took taken taking keep kept keeps keeping tell
told tells telling give gave given gives giving find found finds finding help helped helps helping work worked works working
look looked looks looking turn turned turns turning seem seemed seems seeming show showed shown shows showing move moved moves
moving live lived lives living try tried tries trying ask asked asks asking mean meant means meaning let lets letting put puts
putting say said says saying call called calls calling become became becomes becoming leave left leaves leaving start started
starts starting end ended ends ending stop stopped stops stopping bring brought brings bringing set sets setting talk talked
talks talking a an the and but if or nor as of at by for with about into through before after to from up down in out on off
over under again further once than so yet both either neither whether while since until because though although unless however
therefore thus hence thereby whereby whereas meanwhile nevertheless not no never ever just only even still really very also too
quite rather almost already always often sometimes usually mostly generally actually basically literally honestly probably maybe
perhaps anyway somehow somewhere together around every each now then here there when where why how more most other some such
same own another enough else back well away across along all few many much lot lots little less one two three four five six
several any today yesterday tomorrow tonight morning evening night week month year day days time times moment d ll m re s t ve
didn don won isn wasn aren weren hasn haven hadn couldn wouldn shouldn doesn mustn mightn needn oughtn thing things something
anything everything nothing someone anyone everyone kind right good great like next last long new old big small sure true false
okay ok yeah yes bit way place point part side`.split(/\s+/))

function topWords(entries) {
  const freq = {}
  for (const e of entries) {
    const words = (e.answer || '').toLowerCase().replace(/[‘’]/g, "'")
      .split(/[\s.,!?;:"'()-]+/)
      .map(w => w.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, ''))
      .filter(w => w.length > 4 && !STOP_WORDS.has(w))
    for (const w of words) freq[w] = (freq[w] || 0) + 1
  }
  return Object.entries(freq).filter(([, n]) => n >= 2).sort((a, b) => b[1] - a[1]).slice(0, 12).map(([w]) => w)
}

function comparison(current, previous) {
  if (previous <= 0) return null
  if (current === previous) return { dir: 'flat', pct: 0 }
  return { dir: current > previous ? 'up' : 'down', pct: Math.round(Math.abs(current - previous) / previous * 100) }
}

function closingMessage(stats, week, streak) {
  if (stats.topCategory) {
    const words = week.filter(e => e.category === stats.topCategory).reduce((s, e) => s + wordCount(e.answer), 0)
    if (words > 30) return `you wrote ${words} words\nabout ${(CATEGORY_LABELS[stats.topCategory] || stats.topCategory).toLowerCase()} ✦`
  }
  if (streak >= 7) return `you showed up\n${streak} days in a row ✦`
  if (stats.totalEntries >= 10) return `${stats.totalEntries} entries.\nthat's not nothing ✦`
  return 'keep showing up\nfor yourself ✦'
}

function buildSlides(entries) {
  const answered = entries.filter(e => !e.skipped)
  const thisWeekAll = inGroundWeek(entries, 0)
  const thisWeek = thisWeekAll.filter(e => !e.skipped)
  const lastWeek = inGroundWeek(answered, -1)
  if (!thisWeek.length) {
    return [{ type: 'text', bg: '#1c1610', accent: '#f0c060', headline: 'nothing written\nthis week yet', subtext: "come back once you've journaled — your week starts fresh each Sunday." }]
  }
  const stats = computeStats(thisWeekAll)
  // Current streak isn't week-scoped: it can run past 7 days and shouldn't reset every abstract.
  const streak = currentStreak(answered)
  const lastWeekWords = lastWeek.reduce((s, e) => s + wordCount(e.answer), 0)
  const s = [{ type: 'title' }]

  s.push({ type: 'count', bg: '#271610', accent: '#ff8c42', value: stats.totalEntries, label: 'entries',
    context: stats.totalEntries === 1 ? 'you showed up.' : 'you kept showing up.',
    comparison: comparison(stats.totalEntries, lastWeek.length) })
  s.push({ type: 'count', bg: '#0f2418', accent: '#5edb97', value: stats.totalWords, label: 'words written',
    context: 'every one of them mattered.', comparison: comparison(stats.totalWords, lastWeekWords) })
  if (streak > 1) {
    s.push({ type: 'count', bg: '#22190a', accent: '#ffc840', value: streak, label: 'day streak', context: 'consistency is a form of care.' })
  }
  if (stats.topCategory) {
    s.push({ type: 'text', bg: '#171322', accent: '#C39BD3',
      headline: CATEGORY_LABELS[stats.topCategory] || stats.topCategory,
      subtext: CATEGORY_SUBTEXTS[stats.topCategory] || 'the theme you kept coming back to.' })
  }
  if (stats.mostActiveDay) {
    s.push({ type: 'text', bg: '#101f22', accent: '#60d4e8',
      headline: `you wrote most on ${DAY_NAMES[stats.mostActiveDay]}s`,
      subtext: stats.mostActiveHour != null ? `usually around ${formatHour(stats.mostActiveHour)}` : 'whenever the moment felt right.' })
  }
  const words = topWords(thisWeek)
  if (words.length >= 3) s.push({ type: 'words', bg: '#121218', words })

  const longest = thisWeek.reduce((best, e) => (!best || wordCount(e.answer) > wordCount(best.answer) ? e : best), null)
  const quote = longest && wordCount(longest.answer) > 10 && snippet(longest.answer)
  if (quote) s.push({ type: 'quote', bg: '#0e161c', accent: '#60d4e8', quote, context: 'from your longest entry' })

  if (stats.totalSkips > 0) {
    s.push({ type: 'text', bg: '#1a1222', accent: '#FFA6C9', headline: `${stats.totalSkips} skipped`,
      subtext: stats.skipRate >= 0.5 ? "it's okay — but make some time for yourself to ground." : 'you showed up most of the time. that matters.' })
  }
  s.push({ type: 'closing', message: closingMessage(stats, thisWeek, streak) })
  return s
}

function useCountUp(target, active, duration = 1400) {
  const [value, setValue] = useState(0)
  useEffect(() => {
    if (!active) { setValue(0); return undefined }
    let raf
    const start = performance.now() + 200
    const tick = now => {
      const t = Math.min(Math.max((now - start) / duration, 0), 1)
      setValue(Math.round((1 - Math.pow(1 - t, 3)) * target))
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, active, duration])
  return value
}

function Typewriter({ text, active, delay = 150, speed }) {
  const [shown, setShown] = useState(0)
  useEffect(() => {
    setShown(0)
    if (!active) return undefined
    const step = speed ?? Math.min(40, 1800 / Math.max(1, text.length))
    let i = 0, iv
    const t = setTimeout(() => { iv = setInterval(() => { i++; setShown(i); if (i >= text.length) clearInterval(iv) }, step) }, delay)
    return () => { clearTimeout(t); clearInterval(iv) }
  }, [text, active, delay, speed])
  return <>{text.slice(0, shown)}<span className="abs-ghost">{text.slice(shown)}</span></>
}

// Fixed scatter layout: [dx, dy, rotation, size]
const CLOUD = [[0, 0, 0, 56], [-140, -60, -5, 36], [140, -50, 4, 32], [-120, 80, -3, 28], [130, 85, 6, 26], [8, -130, -4, 24],
  [-50, 140, 3, 22], [170, 10, -2, 20], [-170, 10, 5, 19], [60, -155, 3, 18], [-90, -145, -3, 17], [110, 150, -4, 16]]

function Slide({ def, visible, onClose }) {
  const count = useCountUp(def.value ?? 0, visible && def.type === 'count')
  const cls = `abs-slide${visible ? ' abs-slide--on' : ''}`
  switch (def.type) {
    case 'title':
      return (
        <div className={cls} style={{ background: '#1c1610' }}>
          <p className="abs-eyebrow" style={{ color: '#f0c06066' }}>your week in journaling</p>
          <h1 className="abs-hero" style={{ color: '#f0c060' }}>Abstract ✦</h1>
          <p className="abs-eyebrow abs-hint">tap or press → to begin</p>
        </div>
      )
    case 'count':
      return (
        <div className={cls} style={{ background: def.bg }}>
          <p className="abs-eyebrow" style={{ color: def.accent + '8c' }}>{def.label}</p>
          <p className="abs-num" style={{ color: def.accent }}>{count.toLocaleString()}</p>
          <p className="abs-caption">{def.context}</p>
          {def.comparison && (
            <span className={`abs-compare abs-compare--${def.comparison.dir}`}>
              {def.comparison.dir === 'flat' ? 'same as last week' : `${def.comparison.dir === 'up' ? '↑' : '↓'} ${def.comparison.pct}% vs last week`}
            </span>
          )}
        </div>
      )
    case 'text':
      return (
        <div className={cls} style={{ background: def.bg }}>
          <p className="abs-headline" style={{ color: def.accent }}><Typewriter text={def.headline} active={visible} /></p>
          <p className="abs-caption">{def.subtext}</p>
        </div>
      )
    case 'quote':
      return (
        <div className={cls} style={{ background: def.bg }}>
          <span className="abs-quote-mark" style={{ color: def.accent + '40' }}>“</span>
          <p className="abs-quote"><Typewriter text={def.quote} active={visible} delay={200} speed={Math.min(25, 2500 / def.quote.length)} /></p>
          <p className="abs-eyebrow" style={{ color: def.accent + '66', marginTop: 28 }}>{def.context}</p>
        </div>
      )
    case 'words':
      return (
        <div className={cls} style={{ background: def.bg }}>
          <p className="abs-eyebrow abs-cloud-label">your words</p>
          <div className="abs-cloud">
            {def.words.slice(0, CLOUD.length).map((w, i) => {
              const [dx, dy, rot, size] = CLOUD[i]
              return (
                <span key={w} className="abs-cloud-word" style={{
                  transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) rotate(${rot}deg)`,
                  fontSize: size, opacity: visible ? (i === 0 ? 0.92 : Math.max(0.25, 0.78 - i * 0.06)) : 0,
                  transitionDelay: `${100 + i * 90}ms`,
                }}>{w}</span>
              )
            })}
          </div>
        </div>
      )
    case 'closing':
      return (
        <div className={`${cls} abs-closing`}>
          <p className="abs-eyebrow" style={{ color: '#f0c06059' }}>until next time</p>
          <h2 className="abs-closing-msg">{def.message}</h2>
          {visible && <button className="abs-btn" onClick={e => { e.stopPropagation(); onClose() }}>back to journal</button>}
        </div>
      )
    default:
      return null
  }
}

function Locked({ daysLeft, entriesLeft, onClose }) {
  return (
    <div className="abs-root abs-locked">
      <p className="abs-star">✦</p>
      <h1 className="abs-locked-title">abstract</h1>
      <p className="abs-caption" style={{ maxWidth: 380 }}>a short, visual review of your week in journaling — your patterns, your words.</p>
      <p className="abs-eyebrow" style={{ color: '#f0c06066', marginTop: 32 }}>available after</p>
      <div className="abs-unlock">
        <span className={`abs-unlock-pill${daysLeft === 0 ? ' met' : ''}`}>{daysLeft === 0 ? '7 days ✓' : `${daysLeft} day${daysLeft === 1 ? '' : 's'} left`}</span>
        <span className={`abs-unlock-pill${entriesLeft === 0 ? ' met' : ''}`}>{entriesLeft === 0 ? '10 entries ✓' : `${entriesLeft} entr${entriesLeft === 1 ? 'y' : 'ies'} left`}</span>
      </div>
      <p className="abs-caption" style={{ fontSize: 14, opacity: 0.7 }}>come back on Sunday once you've settled in.</p>
      <button className="abs-btn" onClick={onClose}>back to journal</button>
    </div>
  )
}

export default function Abstract({ entries, onClose }) {
  const answered = entries.filter(e => !e.skipped)
  const { unlocked, daysLeft, entriesLeft } = abstractUnlock(answered)
  const slides = useMemo(() => buildSlides(entries), [entries])
  const [current, setCurrent] = useState(0)
  const last = slides.length - 1

  const advance = useCallback(() => setCurrent(c => Math.min(c + 1, last)), [last])
  const retreat = useCallback(() => setCurrent(c => Math.max(c - 1, 0)), [])

  useEffect(() => {
    const onKey = e => {
      if (e.key === 'ArrowRight' || e.key === ' ') { e.preventDefault(); advance() }
      if (e.key === 'ArrowLeft') retreat()
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [advance, retreat, onClose])

  if (!unlocked) return <Locked daysLeft={daysLeft} entriesLeft={entriesLeft} onClose={onClose} />

  return (
    <div className="abs-root" onClick={advance}>
      {slides.map((def, i) => Math.abs(i - current) <= 1 && (
        <Slide key={i} def={def} visible={i === current} onClose={onClose} />
      ))}
      <div className="abs-noise" aria-hidden="true" />
      <button className="abs-close" onClick={e => { e.stopPropagation(); onClose() }} aria-label="close abstract">✕</button>
      <button className="abs-arrow abs-arrow--left" disabled={current === 0} aria-label="previous slide"
        onClick={e => { e.stopPropagation(); retreat() }}>‹</button>
      <button className="abs-arrow abs-arrow--right" disabled={current === last} aria-label="next slide"
        onClick={e => { e.stopPropagation(); advance() }}>›</button>
      <div className="abs-dots">
        {slides.map((_, i) => (
          <button key={i} className={`abs-dot${i === current ? ' on' : ''}`} aria-label={`slide ${i + 1}`}
            onClick={e => { e.stopPropagation(); setCurrent(i) }} />
        ))}
      </div>
    </div>
  )
}
