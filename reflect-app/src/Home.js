import { useState, useEffect, useCallback } from 'react'
import { supabase } from './supabase'
import Wrapped from './Wrapped'

const QUESTIONS = [
  "What's something you're grateful for right now?",
  "What's one small win you had today?",
  "Who made you smile recently, and why?",
  "What's something you're looking forward to?",
  "What's a moment from today you want to remember?",
  "What's something kind you did or witnessed today?",
  "What gave you energy today?",
  "What's one thing you learned today?",
  "What made today different from yesterday?",
  "What's something beautiful you noticed today?",
  "What are you proud of yourself for?",
  "What's a challenge you handled well recently?",
  "Who are you thinking about fondly right now?",
  "What's a simple pleasure you enjoyed today?",
  "What's something you're excited about?",
  "What did you do today that felt meaningful?",
  "What's something that made you laugh lately?",
  "What's a goal you're making progress on?",
  "What's something you're looking forward to tomorrow?",
  "What's a strength you used today?",
]

const HOURS_BETWEEN_POPUPS = 2

export default function Home({ session }) {
  const [view, setView] = useState('home') // home | journal | history | stats
  const [entries, setEntries] = useState([])
  const [showPopup, setShowPopup] = useState(false)
  const [question, setQuestion] = useState('')
  const [answer, setAnswer] = useState('')
  const [saving, setSaving] = useState(false)
  const [stats, setStats] = useState({ total: 0, streak: 0, thisWeek: 0 })
  const [lastPopup, setLastPopup] = useState(null)
  const [hoursLeft, setHoursLeft] = useState(null)
  const [showWrapped, setShowWrapped] = useState(false)

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
    setQuestion(QUESTIONS[Math.floor(Math.random() * QUESTIONS.length)])
    setAnswer('')
    setShowPopup(true)
  }

  function computeStats(data) {
    const total = data.length
    const now = new Date()
    const oneWeekAgo = new Date(now - 7 * 24 * 3600000)
    const thisWeek = data.filter(e => new Date(e.created_at) > oneWeekAgo).length

    // Streak: consecutive days with at least one entry
    const days = [...new Set(data.map(e => new Date(e.created_at).toDateString()))]
    let streak = 0
    let check = new Date()
    check.setHours(0, 0, 0, 0)
    for (let i = 0; i < 365; i++) {
      if (days.includes(check.toDateString())) {
        streak++
        check.setDate(check.getDate() - 1)
      } else break
    }
    setStats({ total, streak, thisWeek })
  }

  const handleSubmit = async () => {
    if (!answer.trim()) return
    setSaving(true)
    await supabase.from('journal_entries').insert({
      user_id: userId,
      question,
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
    await supabase.from('activity_tracker')
      .upsert({ user_id: userId, last_popup_shown: new Date().toISOString() }, { onConflict: 'user_id' })
    setShowPopup(false)
    setHoursLeft(HOURS_BETWEEN_POPUPS)
  }

  const handleSignOut = () => supabase.auth.signOut()

  return (
    <div className="app">
      {showWrapped && <Wrapped session={session} onClose={() => setShowWrapped(false)} />}
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
          <button className="nav-link wrapped-btn" onClick={() => setShowWrapped(true)}>✦ wrapped</button>
          <button className="nav-link signout" onClick={handleSignOut}>sign out</button>
        </div>
      </nav>

      {/* Home */}
      {view === 'home' && (
        <div className="page">
          <div className="home-hero">
            <h1 className="home-title">hello, {session.user.email.split('@')[0]}</h1>
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
          </div>

          {entries.length > 0 && (
            <div className="recent-section">
              <h2 className="section-title">recent</h2>
              <div className="entries-list">
                {entries.slice(0, 3).map(e => (
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
          {entries.length === 0
            ? <p className="empty">no entries yet — write your first one!</p>
            : <div className="entries-list">
                {entries.map(e => (
                  <div className="entry-card" key={e.id}>
                    <div className="entry-q">{e.question}</div>
                    <div className="entry-a">{e.answer}</div>
                    <div className="entry-date">{new Date(e.created_at).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</div>
                  </div>
                ))}
              </div>
          }
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
              <div className="stats-num">{entries.length > 0 ? Math.round(entries.reduce((a, e) => a + e.answer.split(' ').length, 0) / entries.length) : 0}</div>
              <div className="stats-label">avg words / entry</div>
            </div>
          </div>

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
