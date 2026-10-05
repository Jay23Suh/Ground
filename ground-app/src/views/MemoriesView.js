import { useCallback, useEffect, useMemo, useState } from 'react'
import * as api from '../lib/api'
import { getCollectivePlaces, getCollectiveSeenAt, markCollectiveSeen } from '../lib/storage'
import { SearchBar, FilterPills } from '../components/ui'
import NoteEditor from './NoteEditor'
import SharedMemoryDetail from './SharedMemoryDetail'

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTH_MAP = {
  january: 1, february: 2, march: 3, april: 4, may: 5, june: 6, july: 7, august: 8,
  september: 9, october: 10, november: 11, december: 12,
  jan: 1, feb: 2, mar: 3, apr: 4, jun: 6, jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12,
}

export function displayDate(year, month, day) {
  if (!year) return null
  if (!month) return `${year}`
  if (!day) return `${MONTHS[month - 1]} ${year}`
  return `${MONTHS[month - 1]} ${day}, ${year}`
}

function eventDateParts(ds) {
  const [y, m, d] = (ds || '').split('-').map(Number)
  return y && m && d ? { year: y, month: m, day: d } : { year: null, month: null, day: null }
}

// A personal note and a shared memory, unified into one timeline item.
function toItem(kind, src, places) {
  if (kind === 'note') {
    return {
      key: `n-${src.id}`, kind, src,
      year: src.year, month: src.month, day: src.day,
      title: notePreview(src.content), place: src.place,
    }
  }
  const p = eventDateParts(src.event_date)
  return { key: `s-${src.id}`, kind, src, ...p, title: src.title, place: places[src.id] ?? null }
}

export function notePreview(content) {
  const first = (content || '').split('\n').find(l => l.trim()) ?? ''
  return first ? first.slice(0, 80) : 'empty note'
}

const sortKey = i => (i.year ?? 0) * 10000 + (i.month ?? 0) * 100 + (i.day ?? 0)

function groupItems(items) {
  const byYear = new Map()
  for (const item of [...items].sort((a, b) => sortKey(b) - sortKey(a))) {
    const y = item.year ? String(item.year) : 'undated'
    if (!byYear.has(y)) byYear.set(y, [])
    byYear.get(y).push(item)
  }
  const years = [...byYear.keys()].filter(y => y !== 'undated').sort((a, b) => b - a)
  if (byYear.has('undated')) years.push('undated')
  return years.map(y => {
    const its = byYear.get(y)
    const months = []
    for (let m = 12; m >= 1; m--) {
      const inMonth = its.filter(i => i.month === m)
      if (inMonth.length) months.push({ id: String(m), label: MONTHS[m - 1], items: inMonth })
    }
    const noMonth = its.filter(i => !i.month)
    if (noMonth.length) months.push({ id: 'none', label: null, items: noMonth })
    return { id: y, months }
  })
}

function parseSearch(raw) {
  let year = null, month = null
  const words = []
  for (const token of raw.toLowerCase().split(/\s+/).filter(Boolean)) {
    const n = Number(token)
    if (Number.isInteger(n) && n >= 1900 && n <= 2100) year = n
    else if (MONTH_MAP[token]) month = MONTH_MAP[token]
    else words.push(token)
  }
  return { keyword: words.join(' ') || null, year, month }
}

function MemoryRow({ item, isNew, onOpen }) {
  const meta = [displayDate(item.year, item.month, item.day), item.place].filter(Boolean).join(' · ')
  const shared = item.kind === 'shared'
  return (
    <button className={`memory-row${shared ? ' memory-row--shared' : ''}`} onClick={onOpen}>
      {shared && <span className="memory-shared-icon" aria-hidden="true">👥</span>}
      <span className="memory-body">
        <span className="memory-title">
          {item.title}
          {isNew && <span className="new-dot" aria-label="new activity" />}
        </span>
        {meta && <span className="memory-meta">{meta}</span>}
      </span>
      <span className="top-chevron">›</span>
    </button>
  )
}

export default function MemoriesView({ userId, onNotesChanged, onSeen }) {
  const [notes, setNotes] = useState([])
  const [events, setEvents] = useState([])
  const [activity, setActivity] = useState({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [place, setPlace] = useState(null)
  const [editing, setEditing] = useState(null)
  const [openEvent, setOpenEvent] = useState(null)
  const [drillYear, setDrillYear] = useState(null)
  const [localPlaces, setLocalPlaces] = useState(getCollectivePlaces)
  const [seenAt, setSeenAt] = useState(getCollectiveSeenAt)

  const loadEvents = useCallback(async () => {
    const evs = await api.fetchCollectiveEvents(userId)
    setEvents(evs)
    const persp = await api.fetchCollectivePerspectives(evs.map(e => e.id))
    const act = {}
    for (const ev of evs) {
      const latest = Math.max(0, ...persp.filter(p => p.event_id === ev.id).map(p => Date.parse(p.updated_at)))
      act[ev.id] = Math.max(latest, Date.parse(ev.created_at))
    }
    setActivity(act)
  }, [userId])

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const fetched = await api.fetchNotes(userId)
      setNotes(fetched)
      onNotesChanged(fetched)
      await loadEvents()
    } catch (e) {
      setError(e.message)
    }
    setLoading(false)
  }, [userId, loadEvents, onNotesChanged])

  useEffect(() => { load() }, [load])
  useEffect(() => { onSeen() }, [onSeen])

  useEffect(() => {
    if (!search) { setDebounced(''); return undefined }
    const t = setTimeout(() => setDebounced(search), 250)
    return () => clearTimeout(t)
  }, [search])

  // A note that's been shared is represented once, as its shared memory.
  const allItems = useMemo(() => [
    ...notes.filter(n => !n.collective_event_id).map(n => toItem('note', n, localPlaces)),
    ...events.map(e => toItem('shared', e, localPlaces)),
  ], [notes, events, localPlaces])

  const places = useMemo(() => [...new Set(allItems.map(i => i.place).filter(Boolean))].sort(), [allItems])

  const filtered = useMemo(() => {
    let result = place ? allItems.filter(i => i.place === place) : allItems
    const q = debounced.trim()
    if (!q) return result
    const { keyword, year, month } = parseSearch(q)
    if (keyword) {
      result = result.filter(i => (i.kind === 'note' ? i.src.content : i.src.title).toLowerCase().includes(keyword))
    }
    if (year) result = result.filter(i => i.year === year)
    if (month) result = result.filter(i => i.month === month)
    return result
  }, [allItems, place, debounced])

  const isUnread = useCallback(item => {
    if (item.kind !== 'shared') return false
    const ev = item.src
    const fallback = ev.created_by === userId ? Date.parse(ev.created_at) : 0
    return (activity[ev.id] ?? Date.parse(ev.created_at)) > (seenAt[ev.id] ?? fallback)
  }, [activity, seenAt, userId])

  // Shared memories with unseen activity float to the top.
  const unread = filtered.filter(isUnread).sort((a, b) => (activity[b.src.id] ?? 0) - (activity[a.src.id] ?? 0))
  const groups = groupItems(filtered.filter(i => !isUnread(i)))
  const datedGroups = groupItems(allItems).filter(g => g.id !== 'undated')

  const openShared = ev => {
    markCollectiveSeen(ev.id)
    setSeenAt(getCollectiveSeenAt())
    setOpenEvent(ev)
  }

  const newNote = async () => {
    setError('')
    try {
      setEditing(await api.createNote(userId))
    } catch (e) {
      setError(e.message)
    }
  }

  const jumpTo = id => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })

  if (editing) {
    return (
      <NoteEditor
        userId={userId}
        note={editing}
        onDone={() => { setEditing(null); load() }}
      />
    )
  }

  if (openEvent) {
    return (
      <SharedMemoryDetail
        userId={userId}
        event={openEvent}
        onPlaceChange={() => setLocalPlaces(getCollectivePlaces())}
        onBack={() => { setOpenEvent(null); markCollectiveSeen(openEvent.id); setSeenAt(getCollectiveSeenAt()); loadEvents() }}
      />
    )
  }

  return (
    <div className="page page--memories">
      <div className="page-header">
        <h1 className="page-title">memories</h1>
        <div className="page-actions">
          <button className="icon-btn" onClick={load} aria-label="refresh">↻</button>
          <button className="icon-btn" onClick={newNote} aria-label="new memory">+</button>
        </div>
      </div>

      <SearchBar value={search} onChange={setSearch} placeholder="search by keyword, year, or month…" />
      {places.length > 0 && (
        <FilterPills options={places.map(p => ({ value: p, label: p }))} selected={place} onSelect={setPlace} />
      )}
      {error && <div className="form-error">{error}</div>}

      {loading ? (
        <div className="empty-state"><div className="loading-dot" /></div>
      ) : allItems.length === 0 ? (
        <div className="empty-state">
          <p className="empty">no memories yet</p>
          <p className="empty-hint">write memories, thoughts, anything.</p>
          <button className="btn-link" onClick={newNote}>start writing</button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <p className="empty">no memories found</p>
          <p className="empty-hint">try a keyword, year, or "march 2023"</p>
        </div>
      ) : (
        <div className="memory-list">
          {unread.map(item => <MemoryRow key={item.key} item={item} isNew onOpen={() => openShared(item.src)} />)}
          {groups.map(g => (
            <section key={g.id}>
              <h2 className="memory-year" id={`year-${g.id}`}>{g.id}</h2>
              {g.months.map(m => (
                <div key={m.id}>
                  {m.label && <h3 className="memory-month" id={`month-${g.id}-${m.id}`}>{m.label}</h3>}
                  {m.items.map(item => (
                    <MemoryRow key={item.key} item={item}
                      onOpen={() => item.kind === 'note' ? setEditing(item.src) : openShared(item.src)} />
                  ))}
                </div>
              ))}
            </section>
          ))}
        </div>
      )}

      {datedGroups.length > 0 && !loading && (
        <nav className="timeline-strip" aria-label="jump to date">
          {drillYear ? (
            <>
              <button className="timeline-back" onClick={() => setDrillYear(null)} aria-label="back to years">‹</button>
              <span className="timeline-year">{drillYear}</span>
              {datedGroups.find(g => g.id === drillYear)?.months.filter(m => m.label).map(m => (
                <button key={m.id} className="timeline-chip" onClick={() => jumpTo(`month-${drillYear}-${m.id}`)}>{m.label}</button>
              ))}
            </>
          ) : datedGroups.map(g => (
            <button key={g.id} className="timeline-chip" onClick={() => { jumpTo(`year-${g.id}`); setDrillYear(g.id) }}>{g.id}</button>
          ))}
        </nav>
      )}
    </div>
  )
}
