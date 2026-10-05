import { ReactComponent as LegoIcon } from '../lego.svg'
import QuoteBanner from '../components/QuoteBanner'
import { EntryCard } from '../components/ui'

function greetingSubtitle() {
  const h = new Date().getHours()
  if (h >= 5 && h < 12) return 'good morning. how are you starting the day?'
  if (h >= 12 && h < 17) return 'good afternoon. take a moment to check in.'
  if (h >= 17 && h < 21) return 'good evening. how was your day?'
  return "still up? what's on your mind?"
}

export default function HomeView({ name, quote, stats, entries, minutesLeft, skipNudge, onWrite, onSeeAll }) {
  const recent = entries.filter(e => !e.skipped).slice(0, 3)
  return (
    <div className="page">
      <div className="home-hero">
        <h1 className="home-title">hello, {name}</h1>
        <p className="home-sub">{greetingSubtitle()}</p>
      </div>

      <QuoteBanner quote={quote} />

      <div className="quick-pills">
        <div className="quick-pill"><span className="quick-pill-num">{stats.totalEntries}</span><span className="quick-pill-label">entries</span></div>
        <div className="quick-pill"><span className="quick-pill-num">{stats.totalWords}</span><span className="quick-pill-label">words</span></div>
        {stats.currentStreak > 0 && (
          <div className="quick-pill"><span className="quick-pill-num">{stats.currentStreak}d</span><span className="quick-pill-label">streak</span></div>
        )}
      </div>

      <button className="btn-journal" onClick={onWrite}>
        <LegoIcon style={{ width: 16, height: 16 }} /> write now
      </button>
      <p className="home-next">
        {minutesLeft == null || minutesLeft <= 0
          ? 'your next prompt is ready'
          : minutesLeft < 60
            ? `next prompt in ~${minutesLeft} min`
            : `next prompt in ~${Math.round(minutesLeft / 60)} hour${Math.round(minutesLeft / 60) === 1 ? '' : 's'}`}
      </p>

      {skipNudge && (
        <div className="skip-nudge">hey — make some time for yourself to ground today <LegoIcon style={{ width: 13, height: 13, verticalAlign: 'middle' }} /></div>
      )}

      {recent.length > 0 && (
        <div className="recent-section">
          <h2 className="section-label">recent entries</h2>
          <div className="entries-list">
            {recent.map(e => <EntryCard key={e.id} entry={e} />)}
          </div>
          <button className="btn-more" onClick={onSeeAll}>see all entries →</button>
        </div>
      )}
    </div>
  )
}
