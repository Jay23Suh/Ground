import { useState, useEffect, useCallback } from 'react'
import { supabase, supabaseConfigError } from './supabase'
import Abstract from './Wrapped'
import { ReactComponent as LegoIcon } from './lego.svg'
import { QuoteService } from './services/QuoteService'
import QuoteModal from './components/QuoteModal'
import QuoteBanner from './components/QuoteBanner'

const QUESTIONS = {
  gratitude: [
    "What's something you're grateful for in this exact moment?",
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
    "What value felt strongest in you today?",
    "What's one tiny action you took that moved you toward the life you want?",
    "Where did you choose what mattered over what was easiest today?",
    "What's something you said no to that protected what you care about?",
    "If today had a theme, what would it be?",
  ],
  emotions: [
    "What emotion is most noticeable in you right now?",
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
    "What's a small detail around you that you hadn't noticed before?",
    "What tells you that you are safe enough in this moment?",
    "What's one thing you can let go of, just for the next minute?",
    "What's a small action you could take right now to feel 5% more settled?",
    "If you named this moment as a weather pattern, what would it be?",
  ],
  horizon: [
    "What does a perfectly balanced, ordinary Tuesday look like for you three years down the line?",
    "What mindsets, habits, or fears do you want to leave behind?",
    "If you were a guest on your own podcast five years from now, what would be the title of your episode, and what would be the most surprising pivot in your story?",
    "When looking at the unpredictable or seemingly chaotic parts of your future, where can you find the underlying patterns or peace?",
    "What will be your new anchor for daily discipline and routine?",
    "What is a deeply held assumption about your ideal path that you are willing to let go of to make room for unexpected opportunities?",
    "When you succeed, who is sitting at the table celebrating with you?",
  ],
  community: [
    "How do you want to define \"community\" in your life?",
    "What is your favorite moment of teamwork and connection — what made it feel that way?",
    "Who is your hero, or someone you look up to, and what quality in them do you want to cultivate in yourself?",
    "What is an expectation you hold for the people around you, and do you hold yourself to that same standard?",
    "Who in your life consistently asks you the kinds of questions that make you pause and rethink your assumptions?",
    "If you were to host a dinner party, what is the feeling or atmosphere you want in that room?",
  ],
}

function pickQuestion() {
  const all = Object.entries(QUESTIONS).flatMap(([cat, qs]) =>
    qs.map(q => ({ question: q, category: cat }))
  )
  let queue = JSON.parse(localStorage.getItem('ground_question_queue') || '[]')
  if (queue.length === 0) {
    queue = [...Array(all.length).keys()].sort(() => Math.random() - 0.5)
  }
  const index = queue.shift()
  localStorage.setItem('ground_question_queue', JSON.stringify(queue))
  return all[index] ?? all[0]
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
  horizon:    'Looking Ahead',
  community:  'Community & Connection',
}

function formatHour(h) {
  if (h === 0) return '12am'
  if (h === 12) return '12pm'
  return h < 12 ? `${h}am` : `${h - 12}pm`
}

const CATEGORY_COLORS = {
  gratitude:  '#FFA6C9',
  compassion: '#C39BD3',
  values:     '#76D7C4',
  emotions:   '#F7971D',
  grounding:  '#005499',
  horizon:    '#60d4e8',
  community:  '#5edb97',
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

function HourPatternChart({ hourDist }) {
  const maxCount = Math.max(...hourDist, 1)
  const timeColor = h => {
    if (h >= 5  && h < 9)  return '#F7971D'
    if (h >= 9  && h < 13) return '#C39BD3'
    if (h >= 13 && h < 18) return '#76D7C4'
    if (h >= 18 && h < 22) return '#FFA6C9'
    return '#76D7C4'
  }
  return (
    <div className="section-card">
      <div className="section-card-title">when you write</div>
      <div className="hour-bars">
        {hourDist.map((count, h) => (
          <div className="hour-bar-col" key={h}>
            <div
              className="hour-bar"
              style={{
                height: `${Math.max(2, (count / maxCount) * 48)}px`,
                background: count > 0 ? timeColor(h) : 'var(--card-border)',
                opacity: count > 0 ? 0.8 : 0.3,
              }}
            />
            {h % 6 === 0 && (
              <div className="hour-label">
                {h === 0 ? '12a' : h === 12 ? '12p' : `${h < 12 ? h : h - 12}${h < 12 ? 'a' : 'p'}`}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
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
  const [stats, setStats] = useState({
    total: 0, totalWords: 0, avgWords: 0,
    streak: 0, longestStreak: 0,
    consistency: 0, consistencyWindow: 0,
    thisWeek: 0, totalSkips: 0, skipRate: 0, skipNudge: false,
    mostActiveDay: null, peakHour: null,
    categoryBreakdown: [], hourDist: Array(24).fill(0),
  })
  const [hoursLeft, setHoursLeft] = useState(null)
  const [showAbstract, setShowAbstract] = useState(false)
  const [errorMessage, setErrorMessage] = useState(supabaseConfigError || '')

  // Quote & Settings State
  const [quote, setQuote] = useState(null)
  const [showQuoteModal, setShowQuoteModal] = useState(false)
  const [showSettings, setShowSettings] = useState(false)
  const [profile, setProfile] = useState(null)
  const [quoteStartTime, setQuoteStartTime] = useState('06:00')

  const userId = session.user.id

  const fetchQuote = useCallback(async (currentProfile) => {
    const dailyQuote = await QuoteService.getQuoteOfTheDay()
    setQuote(dailyQuote)
    if (QuoteService.shouldShowModal(currentProfile)) {
      setShowQuoteModal(true)
    }
  }, [])

  const fetchEntries = useCallback(async () => {
    if (!supabase) {
      setErrorMessage(supabaseConfigError)
      return
    }
    const { data, error } = await supabase
      .from('journal_entries')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (error) {
      setErrorMessage(error.message)
      return
    }
    setErrorMessage('')
    if (data) {
      setEntries(data)
      computeStats(data)
    }
  }, [userId])

  const fetchProfileAndQuote = useCallback(async () => {
    if (!supabase) return
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle()
    
    if (error) {
      setErrorMessage(error.message)
      return
    }
    
    if (data) {
      setProfile(data)
      setQuoteStartTime((data.quote_start_time || '06:00:00').slice(0, 5))
    }
    fetchQuote(data)
  }, [userId, fetchQuote])

  const fetchActivityTracker = useCallback(async () => {
    if (!supabase) {
      setErrorMessage(supabaseConfigError)
      return
    }
    const { data, error } = await supabase
      .from('activity_tracker')
      .select('last_popup_shown')
      .eq('user_id', userId)
      .maybeSingle()

    if (error) {
      setErrorMessage(error.message)
      return
    }

    if (data?.last_popup_shown) {
      setErrorMessage('')
      const last = new Date(data.last_popup_shown)
      const hoursPassed = (Date.now() - last.getTime()) / 3600000
      if (hoursPassed >= HOURS_BETWEEN_POPUPS) {
        triggerPopup()
      } else {
        setHoursLeft(Math.ceil(HOURS_BETWEEN_POPUPS - hoursPassed))
      }
    } else {
      // First time user — create the row and show the first prompt.
      const { error: upsertError } = await supabase
        .from('activity_tracker')
        .upsert({ user_id: userId, last_popup_shown: new Date().toISOString() }, { onConflict: 'user_id' })
      if (upsertError) {
        setErrorMessage(upsertError.message)
        return
      }
      setErrorMessage('')
      triggerPopup()
    }
  }, [userId])

  useEffect(() => {
    fetchEntries()
    fetchActivityTracker()
    fetchProfileAndQuote()
  }, [fetchEntries, fetchActivityTracker, fetchProfileAndQuote])

  // Request notification permission once on load
  useEffect(() => {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission()
    }
  }, [])

  // Poll every 5 minutes — fire popup if 2 hours have passed since last
  useEffect(() => {
    if (!supabase) return undefined
    const interval = setInterval(async () => {
      const { data, error } = await supabase
        .from('activity_tracker')
        .select('last_popup_shown')
        .eq('user_id', userId)
        .maybeSingle()
      if (error) {
        setErrorMessage(error.message)
        return
      }
      if (!data?.last_popup_shown) return
      setErrorMessage('')
      const hoursPassed = (Date.now() - new Date(data.last_popup_shown).getTime()) / 3600000
      if (hoursPassed >= HOURS_BETWEEN_POPUPS) {
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('✦ a moment to ground', {
            body: 'time for a quick grounding',
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

  const handleDismissQuote = async () => {
    try {
      await QuoteService.markQuoteAsShown(userId);
      setShowQuoteModal(false);
    } catch (error) {
      setErrorMessage(error.message);
    }
  };

  const handleUpdateProfile = async (updates) => {
    try {
      const { error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId);
      
      if (error) throw error;
      fetchProfileAndQuote();
    } catch (error) {
      setErrorMessage(error.message);
    }
  };

  function computeStats(data) {
    const answered = data.filter(e => !e.skipped && e.answer?.trim())
    const total = answered.length
    const totalWords = answered.reduce((sum, e) => sum + e.answer.trim().split(/\s+/).filter(Boolean).length, 0)
    const avgWords = total > 0 ? Math.round(totalWords / total) : 0

    // Current streak
    const daySet = new Set(answered.map(e => new Date(e.created_at).toDateString()))
    let streak = 0
    const checkDate = new Date(); checkDate.setHours(0, 0, 0, 0)
    for (let i = 0; i < 365; i++) {
      if (daySet.has(checkDate.toDateString())) { streak++; checkDate.setDate(checkDate.getDate() - 1) }
      else break
    }

    // Longest streak
    const allDays = [...daySet].map(d => new Date(d)).sort((a, b) => a - b)
    let longestStreak = 0, cur = 0
    for (let i = 0; i < allDays.length; i++) {
      if (i === 0) { cur = 1 }
      else if ((allDays[i] - allDays[i-1]) / 86400000 === 1) { cur++ }
      else { cur = 1 }
      longestStreak = Math.max(longestStreak, cur)
    }

    // Consistency (days active / window capped at 30)
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const firstDay = allDays.length > 0 ? allDays[0] : today
    const daysSinceFirst = Math.max(1, Math.round((today - firstDay) / 86400000) + 1)
    const window = Math.min(daysSinceFirst, 30)
    let activeDayCount = 0
    for (let i = 0; i < window; i++) {
      const d = new Date(today); d.setDate(today.getDate() - i)
      if (daySet.has(d.toDateString())) activeDayCount++
    }
    const consistency = window > 0 ? Math.round(activeDayCount / window * 100) : 0

    // Most active day of week
    const dayCounts = Array(7).fill(0)
    answered.forEach(e => { dayCounts[new Date(e.created_at).getDay()]++ })
    const maxDayCount = Math.max(...dayCounts)
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    const mostActiveDay = maxDayCount > 0 ? dayNames[dayCounts.indexOf(maxDayCount)] : null

    // Hour distribution
    const hourDist = Array(24).fill(0)
    answered.forEach(e => { hourDist[new Date(e.created_at).getHours()]++ })
    const maxHourCount = Math.max(...hourDist)
    const peakHour = maxHourCount > 0 ? hourDist.indexOf(maxHourCount) : null

    // Category breakdown
    const catCounts = {}
    answered.forEach(e => { if (e.category) catCounts[e.category] = (catCounts[e.category] || 0) + 1 })
    const catTotal = Object.values(catCounts).reduce((a, b) => a + b, 0)
    const categoryBreakdown = Object.entries(catCounts)
      .sort((a, b) => b[1] - a[1])
      .map(([key, count]) => ({ key, label: CATEGORY_LABELS[key] || key, count, pct: catTotal > 0 ? count / catTotal : 0 }))

    const totalSkips = data.filter(e => e.skipped).length
    const totalPrompts = data.length
    const skipRate = totalPrompts > 0 ? Math.round(totalSkips / totalPrompts * 100) : 0
    const thisWeek = answered.filter(e => new Date(e.created_at) > new Date(Date.now() - 7 * 24 * 3600000)).length
    const skipNudge = skipRate > 50 && totalPrompts > 3

    setStats({
      total, totalWords, avgWords, streak, longestStreak,
      consistency, consistencyWindow: window,
      thisWeek, totalSkips, skipRate, skipNudge,
      mostActiveDay, peakHour, categoryBreakdown, hourDist,
    })
  }

  const handleSubmit = async () => {
    if (!supabase) {
      setErrorMessage(supabaseConfigError)
      return
    }
    if (!answer.trim()) return
    setSaving(true)
    setErrorMessage('')
    const { error: entryError } = await supabase.from('journal_entries').insert({
      user_id: userId,
      question,
      category: questionCategory,
      answer: answer.trim(),
    })
    if (entryError) {
      setErrorMessage(entryError.message)
      setSaving(false)
      return
    }
    const { error: activityError } = await supabase.from('activity_tracker')
      .upsert({ user_id: userId, last_popup_shown: new Date().toISOString() }, { onConflict: 'user_id' })
    if (activityError) {
      setErrorMessage(activityError.message)
      setSaving(false)
      return
    }
    setShowPopup(false)
    setHoursLeft(HOURS_BETWEEN_POPUPS)
    fetchEntries()
    setSaving(false)
  }

  const handleSkip = async () => {
    if (!supabase) {
      setErrorMessage(supabaseConfigError)
      return
    }
    setErrorMessage('')
    const { error: entryError } = await supabase.from('journal_entries').insert({
      user_id: userId,
      question,
      category: questionCategory,
      answer: '',
      skipped: true,
    })
    if (entryError) {
      setErrorMessage(entryError.message)
      return
    }
    const { error: activityError } = await supabase.from('activity_tracker')
      .upsert({ user_id: userId, last_popup_shown: new Date().toISOString() }, { onConflict: 'user_id' })
    if (activityError) {
      setErrorMessage(activityError.message)
      return
    }
    setShowPopup(false)
    setHoursLeft(HOURS_BETWEEN_POPUPS)
    fetchEntries()
  }

  const handleSignOut = async () => {
    if (!supabase) {
      setErrorMessage(supabaseConfigError)
      return
    }
    const { error } = await supabase.auth.signOut()
    if (error) setErrorMessage(error.message)
  }

  return (
    <div className="app">
      {showAbstract && <Abstract session={session} onClose={() => setShowAbstract(false)} />}
      
      {/* Quote Modal */}
      {showQuoteModal && <QuoteModal quote={quote} onDismiss={handleDismissQuote} />}

      {/* Settings Sidebar Overlay */}
      {showSettings && (
        <div className="settings-overlay" onClick={() => setShowSettings(false)}>
          <div className="settings-panel" onClick={e => e.stopPropagation()}>
            <div className="settings-header">
              <h2>settings</h2>
              <button className="btn-close" onClick={() => setShowSettings(false)}>×</button>
            </div>

            <div className="settings-group">
              <label className="settings-label">daily grounding</label>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <span className="settings-help" style={{ flex: 1 }}>start each day at</span>
                <input 
                  type="time" 
                  className="settings-control"
                  value={quoteStartTime}
                  onChange={e => {
                    setQuoteStartTime(e.target.value);
                    handleUpdateProfile({ quote_start_time: e.target.value + ':00' });
                  }}
                />
              </div>
              <p className="settings-help">
                This controls when your daily quote resets and the grounding modal appears.
              </p>
            </div>

            <div className="settings-group">
              <label className="settings-label">account</label>
              <div className="settings-control" style={{ opacity: 0.7, borderStyle: 'dashed' }}>
                {session.user.email}
              </div>
            </div>

            <div style={{ marginTop: 'auto' }}>
              <button className="nav-link signout" style={{ width: '100%', padding: '12px', border: '1px solid var(--card-border)' }} onClick={handleSignOut}>
                sign out
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Popup */}
      {showPopup && (
        <div className="popup-overlay">
          <div className="popup">
            <div className="popup-header"><LegoIcon style={{ width: 14, height: 14, verticalAlign: 'middle', marginRight: 6 }} /> a moment to ground</div>
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
        <div className="nav-logo"><LegoIcon style={{ width: 18, height: 18, verticalAlign: 'middle', marginRight: 6 }} /> ground</div>
        <div className="nav-links">
          <button className={view === 'home' ? 'nav-link active' : 'nav-link'} onClick={() => setView('home')}>home</button>
          <button className={view === 'history' ? 'nav-link active' : 'nav-link'} onClick={() => setView('history')}>entries</button>
          <button className={view === 'stats' ? 'nav-link active' : 'nav-link'} onClick={() => setView('stats')}>stats</button>
          <button className="nav-link abstract-btn" onClick={() => setShowAbstract(true)}>✦ abstract</button>
          <button className="nav-link settings-btn" onClick={() => setShowSettings(true)}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
          </button>
        </div>
      </nav>

      {/* Home */}
      {view === 'home' && (
        <div className="page">
          {/* Quote Banner */}
          <QuoteBanner quote={quote} />

          <div className="home-hero">
            <h1 className="home-title">hello, {session.user.user_metadata?.name || session.user.email}</h1>
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
              write now <LegoIcon style={{ width: 16, height: 16, verticalAlign: 'middle', marginLeft: 4 }} />
            </button>
            {stats.skipNudge && (
              <div className="skip-nudge">hey — make some time for yourself to ground today <LegoIcon style={{ width: 13, height: 13, verticalAlign: 'middle' }} /></div>
            )}
            {errorMessage && <div className="skip-nudge">{errorMessage}</div>}
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

          {stats.skipNudge && (
            <div className="skip-nudge" style={{ marginBottom: 24 }}>
              <LegoIcon style={{ width: 13, height: 13, verticalAlign: 'middle', marginRight: 6 }} /> you've been skipping a lot lately — make some time for yourself to ground
            </div>
          )}

          {/* Big three */}
          <div className="stats-grid stats-grid--3" style={{ marginBottom: 12 }}>
            <div className="stats-card stats-card--accent">
              <div className="stats-num">{stats.total}</div>
              <div className="stats-label">entries</div>
            </div>
            <div className="stats-card stats-card--accent">
              <div className="stats-num">{stats.totalWords}</div>
              <div className="stats-label">words written</div>
            </div>
            <div className="stats-card stats-card--accent">
              <div className="stats-num">{stats.totalSkips}</div>
              <div className="stats-label">skipped</div>
            </div>
          </div>

          {/* Secondary stats */}
          <div className="stats-grid stats-grid--4" style={{ marginBottom: 12 }}>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.avgWords || '—'}</div>
              <div className="stats-label">avg words / entry</div>
            </div>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.streak > 0 ? `${stats.streak}d` : '—'}</div>
              <div className="stats-label">current streak</div>
            </div>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.longestStreak > 0 ? `${stats.longestStreak}d` : '—'}</div>
              <div className="stats-label">longest streak</div>
            </div>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.skipRate}%</div>
              <div className="stats-label">skip rate</div>
            </div>
          </div>

          {/* Consistency row */}
          <div className="stats-grid stats-grid--3" style={{ marginBottom: 24 }}>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.consistency}%</div>
              <div className="stats-label">{stats.consistencyWindow}d consistency</div>
            </div>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.mostActiveDay || '—'}</div>
              <div className="stats-label">most active day</div>
            </div>
            <div className="stats-card">
              <div className="stats-num stats-num--sm">{stats.peakHour != null ? formatHour(stats.peakHour) : '—'}</div>
              <div className="stats-label">peak hour</div>
            </div>
          </div>

          {stats.categoryBreakdown.length > 0 && (
            <CategoryBreakdown breakdown={stats.categoryBreakdown} />
          )}

          <HourPatternChart hourDist={stats.hourDist} />

          <EntryChart entries={entries} />
        </div>
      )}
    </div>
  )
}
