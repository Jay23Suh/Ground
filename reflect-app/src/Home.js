import { useState, useEffect, useCallback } from 'react'
import { supabase } from './supabase'
import Abstract from './Wrapped'

const QUESTIONS = {
  gratitude: [
    "What's something you're grateful for in this exact moment?",
    "What's one thing about your body you appreciate today?",
    "What's something in your surroundings you feel thankful for?",
    "What's a routine or habit you're glad you have?",
    "What's a comfort you enjoyed today — food, warmth, rest, music?",
    "Who are you grateful for today, and why?",
    "What's a past version of you that you feel thankful for?",
    "What's something you have now that you once really wanted?",
    "What's a piece of advice you're grateful you received?",
    "What's a small joy from today you don't want to overlook?",
  ],
  compassion: [
    "How can you be a little gentler with yourself right now?",
    "What's one thing you're willing to forgive yourself for today?",
    "What's something you're struggling with that deserves kindness, not criticism?",
    "How did you show up for yourself today, even in a tiny way?",
    "What's a mistake you can treat as a lesson instead of a failure?",
    "Who could use a bit of understanding from you right now?",
    "What's one kind thought you can offer yourself?",
    "What's a limit or boundary you honored that protected your energy?",
    "What's one way you could make tomorrow a bit easier on yourself?",
    "If a close friend felt like you do now, what would you say to them?",
  ],
  values: [
    "What mattered most to you about today?",
    "What did you do today that felt aligned with your values?",
    "What's an area of life where you want to show up more fully?",
    "What gave you a sense of purpose today, even briefly?",
    "What kind of person do you want to be in small, daily moments?",
    "What value — honesty, curiosity, kindness — felt strongest in you today?",
    "What's one tiny action you took that moved you toward the life you want?",
    "Where did you choose what mattered over what was easiest today?",
    "What's something you said no to that protected what you care about?",
    "If today had a theme, what would it be?",
  ],
  emotions: [
    "What emotion is most noticeable in you right now?",
    "Where did you feel that emotion in your body today?",
    "What's something that felt surprisingly heavy today?",
    "What's something that felt surprisingly light or easy today?",
    "What emotion did you try to push away, and why?",
    "When did you feel most at ease today?",
    "When did you feel most tense or on edge?",
    "What do you wish you could say out loud that you're holding inside?",
    "What's one emotion you can allow, just for a few breaths?",
    "What helped you regulate or soothe yourself today, even a little?",
  ],
  grounding: [
    "What sensations can you feel in your body right now?",
    "What are three things you can see, two you can hear, and one you can feel?",
    "What does your breathing actually feel like in this moment?",
    "What's one place in your body that feels okay or neutral?",
    "What's a small detail around you that you hadn't noticed before?",
    "What tells you that you are safe enough in this moment?",
    "How does your body feel when you gently unclench your jaw and shoulders?",
    "What's one thing you can let go of, just for the next minute?",
    "What's a small action you could take right now to feel 5% more settled?",
    "If you named this moment as a weather pattern, what would it be?",
  ],
}

function pickQuestion() {
  const categories = Object.keys(QUESTIONS)
  const category = categories[Math.floor(Math.random() * categories.length)]
  const list = QUESTIONS[category]
  const question = list[Math.floor(Math.random() * list.length)]
  return { question, category }
}

function buildBuckets(entries, period) {
  const now = new Date()
  const buckets = []
  const pad = n => String(n).padStart(2, '0')
  const toLocalDate = d => `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`
  const todayStr = toLocalDate(now)

  if (period === 'day') {
    for (let h = 0; h < 24; h++) {
      const label = h === 0 ? '12am' : h === 12 ? '12pm' : h % 6 === 0 ? (h < 12 ? `${h}am` : `${h-12}pm`) : ''
      buckets.push({ label, hour: h })
    }
  } else if (period === 'week') {
    // Mon–Sun of the current week
    const monday = new Date(now)
    monday.setDate(now.getDate() - ((now.getDay() + 6) % 7))
    monday.setHours(0, 0, 0, 0)
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
    for (let i = 0; i < 7; i++) {
      const start = new Date(monday); start.setDate(monday.getDate() + i)
      const end   = new Date(start);  end.setDate(start.getDate() + 1)
      buckets.push({ label: days[i], start, end })
    }
  } else if (period === 'month') {
    // Weeks within the current month
    const y = now.getFullYear(), m = now.getMonth()
    const firstDay = new Date(y, m, 1)
    const lastDay  = new Date(y, m + 1, 0)
    let weekStart = new Date(firstDay)
    let weekNum = 1
    while (weekStart <= lastDay) {
      const weekEnd = new Date(weekStart); weekEnd.setDate(weekStart.getDate() + 7)
      buckets.push({ label: `Wk ${weekNum}`, start: new Date(weekStart), end: weekEnd })
      weekStart.setDate(weekStart.getDate() + 7)
      weekNum++
    }
  } else if (period === 'year') {
    // Jan–Dec of the current year
    const y = now.getFullYear()
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
    for (let m = 0; m < 12; m++) {
      buckets.push({ label: months[m], start: new Date(y, m, 1), end: new Date(y, m + 1, 1) })
    }
  }

  return buckets.map(b => ({
    ...b,
    count: entries.filter(e => {
      const d = new Date(e.created_at)
      if (period === 'day') return toLocalDate(d) === todayStr && d.getHours() === b.hour
      return d >= b.start && d < b.end
    }).length,
  }))
}

function EntryChart({ entries }) {
  const [period, setPeriod] = useState('week')
  const buckets = buildBuckets(entries, period)
  const maxCount = Math.max(...buckets.map(b => b.count), 1)

  const W = 600, H = 170, padL = 28, padB = 28, padR = 12, padT = 22
  const chartW = W - padL - padR
  const chartH = H - padT - padB
  const barW = Math.max(4, (chartW / buckets.length) * 0.6)
  const gap   = chartW / buckets.length

  const rawTicks = maxCount <= 4
    ? Array.from({ length: maxCount + 1 }, (_, i) => i)
    : [0, Math.round(maxCount / 4), Math.round(maxCount / 2), Math.round(3 * maxCount / 4), maxCount]
  const yTicks = [...new Set(rawTicks)]

  return (
    <div className="chart-card">
      <div className="chart-header">
        <span className="chart-title">entries over time</span>
        <div className="chart-toggles">
          {['day','week','month','year'].map(p => (
            <button key={p} className={`chart-pill${period === p ? ' active' : ''}`} onClick={() => setPeriod(p)}>{p}</button>
          ))}
        </div>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
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
          const y = padT + chartH - barH
          return (
            <g key={i}>
              <rect x={x} y={y} width={barW} height={Math.max(barH, b.count > 0 ? 2 : 0)}
                rx="3" fill={b.count > 0 ? 'var(--lavender)' : 'rgba(195,155,211,0.15)'} opacity="0.85" />
              {b.label && (
                <text x={padL + i * gap + gap / 2} y={H - 4} textAnchor="middle"
                  fontSize="9" className="chart-label" fontFamily="Space Mono, monospace">{b.label}</text>
              )}
            </g>
          )
        })}
      </svg>
    </div>
  )
}

const CATEGORY_LABELS = {
  gratitude:  'Gratitude',
  compassion: 'Self-Compassion',
  values:     'Values & Meaning',
  emotions:   'Emotions',
  grounding:  'Present Moment',
}

function HistoryView({ entries }) {
  const [activeCategory, setActiveCategory] = useState('all')

  const categories = ['all', ...Object.keys(CATEGORY_LABELS).filter(c =>
    entries.some(e => e.category === c)
  )]

  const filtered = activeCategory === 'all'
    ? entries
    : entries.filter(e => e.category === activeCategory)

  return entries.length === 0
    ? <p className="empty">no entries yet — write your first one!</p>
    : <>
        <div className="category-filters">
          {categories.map(c => (
            <button
              key={c}
              className={`category-pill${activeCategory === c ? ' active' : ''}`}
              onClick={() => setActiveCategory(c)}
            >
              {c === 'all' ? 'All' : CATEGORY_LABELS[c]}
            </button>
          ))}
        </div>
        <div className="entries-list">
          {filtered.map(e => (
            <div className="entry-card" key={e.id}>
              {e.category && (
                <div className={`entry-category entry-category--${e.category}`}>
                  {CATEGORY_LABELS[e.category] || e.category}
                </div>
              )}
              <div className="entry-q">{e.question}</div>
              <div className="entry-a">{e.answer}</div>
              <div className="entry-date">{new Date(e.created_at).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</div>
            </div>
          ))}
        </div>
      </>
}

const HOURS_BETWEEN_POPUPS = 2

export default function Home({ session }) {
  const [view, setView] = useState('home') // home | journal | history | stats
  const [entries, setEntries] = useState([])
  const [showPopup, setShowPopup] = useState(false)
  const [question, setQuestion] = useState('')
  const [questionCategory, setQuestionCategory] = useState('')
  const [answer, setAnswer] = useState('')
  const [saving, setSaving] = useState(false)
  const [stats, setStats] = useState({ total: 0, streak: 0, thisWeek: 0, totalSkips: 0, skipNudge: false })
  const [lastPopup, setLastPopup] = useState(null)
  const [hoursLeft, setHoursLeft] = useState(null)
  const [showAbstract, setShowAbstract] = useState(false)

  const userId = session.user.id

  const fetchEntries = useCallback(async () => {
    const { data } = await supabase
      .from('journal_entries')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (data) {
      setEntries(data)
      computeStats(data)
    }
  }, [userId])

  const fetchActivityTracker = useCallback(async () => {
    const { data } = await supabase
      .from('activity_tracker')
      .select('last_popup_shown')
      .eq('user_id', userId)
      .single()

    if (data?.last_popup_shown) {
      const last = new Date(data.last_popup_shown)
      setLastPopup(last)
      const hoursPassed = (Date.now() - last.getTime()) / 3600000
      if (hoursPassed >= HOURS_BETWEEN_POPUPS) {
        triggerPopup()
      } else {
        setHoursLeft(Math.ceil(HOURS_BETWEEN_POPUPS - hoursPassed))
      }
    } else {
      // First time user — insert row and show popup
      await supabase.from('activity_tracker').insert({ user_id: userId, last_popup_shown: new Date().toISOString() })
      triggerPopup()
    }
  }, [userId])

  useEffect(() => {
    fetchEntries()
    fetchActivityTracker()
  }, [fetchEntries, fetchActivityTracker])

  // Request notification permission once on load
  useEffect(() => {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission()
    }
  }, [])

  // Poll every 5 minutes — fire popup if 2 hours have passed since last
  useEffect(() => {
    const interval = setInterval(async () => {
      const { data } = await supabase
        .from('activity_tracker')
        .select('last_popup_shown')
        .eq('user_id', userId)
        .single()
      if (!data?.last_popup_shown) return
      const hoursPassed = (Date.now() - new Date(data.last_popup_shown).getTime()) / 3600000
      if (hoursPassed >= HOURS_BETWEEN_POPUPS) {
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('✦ a moment to reflect', {
            body: 'time for a quick reflection',
            icon: '/favicon.ico',
          })
        }
        triggerPopup()
        setHoursLeft(null)
      } else {
        setHoursLeft(Math.ceil(HOURS_BETWEEN_POPUPS - hoursPassed))
      }
    }, 5 * 60 * 1000) // every 5 minutes
    return () => clearInterval(interval)
  }, [userId])

  function triggerPopup() {
    const { question, category } = pickQuestion()
    setQuestion(question)
    setQuestionCategory(category)
    setAnswer('')
    setShowPopup(true)
  }

  function computeStats(data) {
    const answered = data.filter(e => !e.skipped)
    const total = answered.length
    const now = new Date()
    const oneWeekAgo = new Date(now - 7 * 24 * 3600000)
    const thisWeek = answered.filter(e => new Date(e.created_at) > oneWeekAgo).length

    // Streak: consecutive days with at least one answered entry
    const days = [...new Set(answered.map(e => new Date(e.created_at).toDateString()))]
    let streak = 0
    let check = new Date()
    check.setHours(0, 0, 0, 0)
    for (let i = 0; i < 365; i++) {
      if (days.includes(check.toDateString())) {
        streak++
        check.setDate(check.getDate() - 1)
      } else break
    }

    // Skip nudge: more skips than answers today
    const todayStr = new Date().toDateString()
    const todayAll = data.filter(e => new Date(e.created_at).toDateString() === todayStr)
    const todaySkips = todayAll.filter(e => e.skipped).length
    const todayAnswered = todayAll.filter(e => !e.skipped).length
    const skipNudge = todaySkips > 0 && todaySkips > todayAnswered

    const totalSkips = data.filter(e => e.skipped).length
    setStats({ total, streak, thisWeek, totalSkips, skipNudge })
  }

  const handleSubmit = async () => {
    if (!answer.trim()) return
    setSaving(true)
    await supabase.from('journal_entries').insert({
      user_id: userId,
      question,
      category: questionCategory,
      answer: answer.trim(),
    })
    await supabase.from('activity_tracker')
      .upsert({ user_id: userId, last_popup_shown: new Date().toISOString() }, { onConflict: 'user_id' })
    setShowPopup(false)
    setHoursLeft(HOURS_BETWEEN_POPUPS)
    fetchEntries()
    setSaving(false)
  }

  const handleSkip = async () => {
    await supabase.from('journal_entries').insert({
      user_id: userId,
      question,
      category: questionCategory,
      skipped: true,
    })
    await supabase.from('activity_tracker')
      .upsert({ user_id: userId, last_popup_shown: new Date().toISOString() }, { onConflict: 'user_id' })
    setShowPopup(false)
    setHoursLeft(HOURS_BETWEEN_POPUPS)
    fetchEntries()
  }

  const handleSignOut = () => supabase.auth.signOut()

  return (
    <div className="app">
      {showAbstract && <Abstract session={session} onClose={() => setShowAbstract(false)} />}
      {/* Popup */}
      {showPopup && (
        <div className="popup-overlay">
          <div className="popup">
            <div className="popup-header">✦ a moment to reflect</div>
            <div className="popup-question">{question}</div>
            <textarea
              className="popup-textarea"
              placeholder="write freely..."
              value={answer}
              onChange={e => setAnswer(e.target.value)}
              autoFocus
            />
            <div className="popup-btns">
              <button className="btn-skip" onClick={handleSkip}>Skip</button>
              <button className="btn-save" onClick={handleSubmit} disabled={saving}>
                {saving ? '...' : 'Save ↵'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Nav */}
      <nav className="nav">
        <div className="nav-logo">✦ reflect</div>
        <div className="nav-links">
          <button className={view === 'home' ? 'nav-link active' : 'nav-link'} onClick={() => setView('home')}>home</button>
          <button className={view === 'history' ? 'nav-link active' : 'nav-link'} onClick={() => setView('history')}>entries</button>
          <button className={view === 'stats' ? 'nav-link active' : 'nav-link'} onClick={() => setView('stats')}>stats</button>
          <button className="nav-link abstract-btn" onClick={() => setShowAbstract(true)}>✦ abstract</button>
          <button className="nav-link signout" onClick={handleSignOut}>sign out</button>
        </div>
      </nav>

      {/* Home */}
      {view === 'home' && (
        <div className="page">
          <div className="home-hero">
            <h1 className="home-title">hello, {session.user.user_metadata?.name}</h1>
            <p className="home-sub">
              {hoursLeft
                ? `next prompt in ~${hoursLeft} hour${hoursLeft !== 1 ? 's' : ''}`
                : 'your next prompt is ready'}
            </p>
            <div className="home-stats-row">
              <div className="stat-pill">{stats.streak} day streak 🔥</div>
              <div className="stat-pill">{stats.thisWeek} this week</div>
              <div className="stat-pill">{stats.total} total entries</div>
            </div>
            <button className="btn-journal" onClick={triggerPopup}>
              write now ✦
            </button>
            {stats.skipNudge && (
              <div className="skip-nudge">hey — make some time for yourself to reflect today ✦</div>
            )}
          </div>

          {entries.filter(e => !e.skipped).length > 0 && (
            <div className="recent-section">
              <h2 className="section-title">recent</h2>
              <div className="entries-list">
                {entries.filter(e => !e.skipped).slice(0, 3).map(e => (
                  <div className="entry-card" key={e.id}>
                    <div className="entry-q">{e.question}</div>
                    <div className="entry-a">{e.answer}</div>
                    <div className="entry-date">{new Date(e.created_at).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</div>
                  </div>
                ))}
              </div>
              <button className="btn-more" onClick={() => setView('history')}>see all entries →</button>
            </div>
          )}
        </div>
      )}

      {/* History */}
      {view === 'history' && (
        <div className="page">
          <h1 className="page-title">your entries</h1>
          <HistoryView entries={entries} />
        </div>
      )}

      {/* Stats */}
      {view === 'stats' && (
        <div className="page">
          <h1 className="page-title">your stats</h1>
          <div className="stats-grid">
            <div className="stats-card big">
              <div className="stats-num">{stats.streak}</div>
              <div className="stats-label">day streak 🔥</div>
            </div>
            <div className="stats-card">
              <div className="stats-num">{stats.total}</div>
              <div className="stats-label">total entries</div>
            </div>
            <div className="stats-card">
              <div className="stats-num">{stats.thisWeek}</div>
              <div className="stats-label">this week</div>
            </div>
            <div className="stats-card">
              <div className="stats-num">{entries.filter(e => !e.skipped).length > 0 ? Math.round(entries.filter(e => !e.skipped).reduce((a, e) => a + (e.answer || '').split(' ').length, 0) / entries.filter(e => !e.skipped).length) : 0}</div>
              <div className="stats-label">avg words / entry</div>
            </div>
            <div className="stats-card">
              <div className="stats-num">{stats.totalSkips}</div>
              <div className="stats-label">skipped</div>
            </div>
          </div>

          <EntryChart entries={entries} />

          {lastPopup && (
            <div className="last-popup-info">
              last reflection: {lastPopup.toLocaleString()}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
