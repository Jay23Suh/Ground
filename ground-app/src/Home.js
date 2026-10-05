import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import * as api from './lib/api'
import { pickQuestion } from './lib/questions'
import { computeStats } from './lib/stats'
import { getCollectiveLastCheck, getPopupInterval, readJSON, setCollectiveLastCheck, writeJSON } from './lib/storage'
import { ReactComponent as LegoIcon } from './lego.svg'
import { QuoteService } from './services/QuoteService'
import QuoteModal from './components/QuoteModal'
import JournalPopup from './views/JournalPopup'
import HomeView from './views/HomeView'
import HistoryView from './views/HistoryView'
import MemoriesView from './views/MemoriesView'
import StatsView from './views/StatsView'
import SettingsView from './views/SettingsView'
import Abstract from './views/Abstract'
import IntroOverlay from './views/IntroOverlay'

const TABS = ['home', 'history', 'memories', 'stats', 'abstract', 'settings']
const SYNC_MS = 5 * 60 * 1000

function notify(body) {
  if ('Notification' in window && Notification.permission === 'granted' && document.hidden) {
    new Notification('✦ a moment to ground', { body, icon: '/favicon.ico' })
  }
}

export default function Home({ session }) {
  const userId = session.user.id
  const [tab, setTab] = useState('home')
  const [entries, setEntries] = useState([])
  const [notes, setNotes] = useState([])
  const [profile, setProfile] = useState(null)
  const [prompt, setPrompt] = useState(null)
  const [quote, setQuote] = useState(null)
  const [showQuoteModal, setShowQuoteModal] = useState(false)
  const [lastPopup, setLastPopup] = useState(null)
  const [now, setNow] = useState(Date.now())
  const [intervalMin, setIntervalMin] = useState(getPopupInterval)
  const [historyTarget, setHistoryTarget] = useState(null)
  const [badge, setBadge] = useState(0)
  const [error, setError] = useState('')
  const introKey = `ground_intro_seen_${userId}`
  const [showIntro, setShowIntro] = useState(() => !readJSON(introKey, false))
  const promptOpen = useRef(false)
  promptOpen.current = !!prompt

  const stats = useMemo(() => computeStats(entries), [entries])
  const name = session.user.user_metadata?.name || session.user.email?.split('@')[0] || 'there'

  const loadEntries = useCallback(async () => {
    try {
      setEntries(await api.fetchEntries(userId))
      setError('')
    } catch (e) {
      setError(e.message)
    }
  }, [userId])

  const loadProfile = useCallback(async () => {
    try {
      const p = await api.fetchProfile(userId)
      setProfile(p)
      return p
    } catch (e) {
      setError(e.message)
      return null
    }
  }, [userId])

  const openPrompt = useCallback(() => {
    if (promptOpen.current) return
    setPrompt(pickQuestion())
  }, [])

  // Timer-driven prompt: restart the countdown as soon as the prompt shows, so
  // closing it without answering doesn't bring it straight back.
  const firePrompt = useCallback(async () => {
    if (promptOpen.current) return
    openPrompt()
    notify('time for a quick grounding')
    setLastPopup(Date.now())
    try { await api.startActivity(userId) } catch (e) { setError(e.message) }
  }, [openPrompt, userId])

  const syncActivity = useCallback(async () => {
    try {
      const last = await api.fetchLastPopup(userId)
      if (last) setLastPopup(Date.parse(last))
      else firePrompt() // first visit — start the clock with a prompt
    } catch (e) {
      setError(e.message)
    }
  }, [userId, firePrompt])

  // Count new perspectives others submitted on shared memories since the last check.
  const checkCollective = useCallback(async () => {
    try {
      const lastCheck = getCollectiveLastCheck()
      setCollectiveLastCheck(Date.now())
      const events = await api.fetchCollectiveEvents(userId)
      if (!events.length) return
      const persp = await api.fetchCollectivePerspectives(events.map(e => e.id))
      const fresh = persp.filter(p => p.user_id !== userId && p.submitted && Date.parse(p.updated_at) > lastCheck)
      fresh.forEach(p => {
        const ev = events.find(e => e.id === p.event_id)
        notify(`${api.handle(p.author)} added their memory to "${ev?.title}"`)
      })
      if (fresh.length) setBadge(b => b + fresh.length)
    } catch {
      // Badge is best-effort.
    }
  }, [userId])

  useEffect(() => {
    loadEntries()
    syncActivity()
    checkCollective()
    api.fetchNotes(userId).then(setNotes).catch(() => {})
    ;(async () => {
      const p = await loadProfile()
      const q = await QuoteService.getQuoteOfTheDay()
      setQuote(q)
      if (QuoteService.shouldShowModal((p?.quote_start_time || '08:00').slice(0, 5))) {
        setShowQuoteModal(true)
        notify(`"${q.q}" — ${q.a}`)
      }
    })()
  }, [userId, loadEntries, syncActivity, checkCollective, loadProfile])

  // Re-sync when the tab comes back, and periodically for cross-device changes.
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState !== 'visible') return
      loadEntries()
      syncActivity()
      checkCollective()
    }
    document.addEventListener('visibilitychange', onVisible)
    const sync = setInterval(() => { syncActivity(); checkCollective() }, SYNC_MS)
    const tick = setInterval(() => setNow(Date.now()), 30 * 1000)
    return () => { document.removeEventListener('visibilitychange', onVisible); clearInterval(sync); clearInterval(tick) }
  }, [loadEntries, syncActivity, checkCollective])

  const minutesLeft = lastPopup == null ? null : Math.ceil(intervalMin - (now - lastPopup) / 60000)

  useEffect(() => {
    if (minutesLeft != null && minutesLeft <= 0 && !showIntro) firePrompt()
  }, [minutesLeft, showIntro, firePrompt])

  const handleSave = async answer => {
    await api.saveEntry(userId, prompt.question, prompt.category, answer)
    setPrompt(null)
    setLastPopup(Date.now())
    loadEntries()
  }

  const handleSkip = async () => {
    await api.saveSkip(userId, prompt.question, prompt.category)
    setPrompt(null)
    setLastPopup(Date.now())
    loadEntries()
  }

  const finishIntro = () => {
    writeJSON(introKey, true)
    setShowIntro(false)
  }

  const selectEntry = useCallback(id => { setHistoryTarget(id); setTab('history') }, [])
  const clearHistoryTarget = useCallback(() => setHistoryTarget(null), [])
  const clearBadge = useCallback(() => setBadge(0), [])

  return (
    <div className="app">
      {showIntro && <IntroOverlay onDone={finishIntro} />}
      {tab === 'abstract' && <Abstract entries={entries} onClose={() => setTab('home')} />}
      {showQuoteModal && !showIntro && (
        <QuoteModal quote={quote} onDismiss={() => { QuoteService.markQuoteAsShown(); setShowQuoteModal(false) }} />
      )}
      {prompt && !showIntro && (
        <JournalPopup
          key={prompt.question}
          question={prompt.question}
          category={prompt.category}
          onSave={handleSave}
          onSkip={handleSkip}
          onClose={() => setPrompt(null)}
        />
      )}

      <nav className="nav">
        <button className="nav-logo" onClick={() => setTab('home')}>
          <LegoIcon style={{ width: 18, height: 18 }} /> ground
        </button>
        <div className="nav-links">
          {TABS.map(t => (
            <button key={t} className={`nav-link${tab === t ? ' active' : ''}`} onClick={() => setTab(t)}
              aria-current={tab === t ? 'page' : undefined}>
              {t}
              {t === 'memories' && badge > 0 && <span className="nav-badge" aria-label={`${badge} new`} />}
            </button>
          ))}
        </div>
      </nav>

      {error && <div className="error-banner">{error}</div>}

      {(tab === 'home' || tab === 'abstract') && (
        <HomeView
          name={name}
          quote={quote}
          stats={stats}
          entries={entries}
          minutesLeft={minutesLeft}
          skipNudge={stats.skipRate > 0.5 && stats.totalPrompts > 3}
          onWrite={openPrompt}
          onSeeAll={() => setTab('history')}
        />
      )}
      {tab === 'history' && <HistoryView entries={entries} scrollTarget={historyTarget} onScrolled={clearHistoryTarget} />}
      {tab === 'memories' && <MemoriesView userId={userId} onNotesChanged={setNotes} onSeen={clearBadge} />}
      {tab === 'stats' && <StatsView entries={entries} stats={stats} notes={notes} onSelectEntry={selectEntry} />}
      {tab === 'settings' && (
        <SettingsView
          session={session}
          profile={profile}
          onProfileChange={loadProfile}
          onIntervalChange={() => setIntervalMin(getPopupInterval())}
        />
      )}
    </div>
  )
}
