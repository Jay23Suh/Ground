import { useCallback, useEffect, useRef, useState } from 'react'
import * as api from '../lib/api'
import { getRecentPlaces, pushRecentPlace, setCollectivePlace } from '../lib/storage'
import { Popover } from '../components/ui'
import { displayDate } from './MemoriesView'

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const daysIn = (year, month) => new Date(year || 2024, month, 0).getDate()

function DatePicker({ year, month, day, onChange }) {
  const [yearText, setYearText] = useState(year ? String(year) : '')
  const y = Number(yearText) || null
  const setYear = text => {
    setYearText(text)
    const n = Number(text)
    onChange(Number.isInteger(n) && n > 0 ? { year: n, month, day } : { year: null, month: null, day: null })
  }
  return (
    <div className="picker">
      <div className="picker-title">date</div>
      <label className="picker-row">
        <span>year</span>
        <input className="picker-input" inputMode="numeric" placeholder="e.g. 2021" value={yearText}
          onChange={e => setYear(e.target.value.replace(/\D/g, '').slice(0, 4))} />
      </label>
      {y && (
        <label className="picker-row">
          <span>month</span>
          <select className="picker-input" value={month ?? ''}
            onChange={e => onChange({ year: y, month: e.target.value ? Number(e.target.value) : null, day: null })}>
            <option value="">—</option>
            {MONTH_NAMES.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
          </select>
        </label>
      )}
      {y && month && (
        <label className="picker-row">
          <span>day</span>
          <select className="picker-input" value={day ?? ''}
            onChange={e => onChange({ year: y, month, day: e.target.value ? Number(e.target.value) : null })}>
            <option value="">—</option>
            {Array.from({ length: daysIn(y, month) }, (_, i) => <option key={i} value={i + 1}>{i + 1}</option>)}
          </select>
        </label>
      )}
      <button className="btn-link" onClick={() => { setYearText(''); onChange({ year: null, month: null, day: null }) }}>clear</button>
    </div>
  )
}

export function PlacePicker({ place, onChange }) {
  const [text, setText] = useState(place ?? '')
  const recent = getRecentPlaces()
  const commit = value => {
    const clean = value.trim().toLowerCase()
    if (!clean) { onChange(null); return }
    pushRecentPlace(clean)
    onChange(clean)
  }
  return (
    <div className="picker">
      <div className="picker-title">place</div>
      <input className="picker-input picker-input--full" placeholder="e.g. home, café, park" value={text} autoFocus
        onChange={e => setText(e.target.value)}
        onKeyDown={e => e.key === 'Enter' && commit(text)}
        onBlur={() => commit(text)} />
      {recent.length > 0 && (
        <div className="chip-row">
          {recent.map(p => <button key={p} className="chip" onClick={() => { setText(p); commit(p) }}>{p}</button>)}
        </div>
      )}
      {place && <button className="btn-link" onClick={() => { setText(''); onChange(null) }}>clear</button>}
    </div>
  )
}

function SharePanel({ userId, note, content, dateStr, eventId, onShared }) {
  const [title, setTitle] = useState('')
  const [friends, setFriends] = useState([])
  const [members, setMembers] = useState([])
  const [handleText, setHandleText] = useState('')
  const [status, setStatus] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    api.fetchFriends(userId).then(setFriends).catch(() => setFriends([]))
    if (eventId) api.fetchEventMembers(eventId).then(setMembers).catch(() => {})
  }, [userId, eventId])

  const canInvite = !!eventId || !!title.trim()

  const invite = async profile => {
    if (!canInvite) { setStatus('give this memory a title before sharing'); return }
    setBusy(true)
    setStatus('')
    try {
      const id = await api.shareNote(userId, {
        noteId: note.id, noteContent: content, title: title.trim(),
        noteDateStr: dateStr, existingEventId: eventId, addUserId: profile.id,
      })
      if (!eventId && note.place) setCollectivePlace(id, note.place)
      setMembers(m => [...m, profile])
      onShared(id)
    } catch (e) {
      setStatus(e.message)
    }
    setBusy(false)
  }

  const addByHandle = async () => {
    const q = handleText.trim().replace(/^@/, '').toLowerCase()
    if (!q || !canInvite) return
    setBusy(true)
    try {
      const found = await api.searchUser(userId, q)
      if (!found) setStatus('no user found with that handle')
      else if (members.some(m => m.id === found.id)) setStatus('already sharing with this person')
      else { setHandleText(''); setBusy(false); await invite(found); return }
    } catch (e) {
      setStatus(e.message)
    }
    setBusy(false)
  }

  const uninvited = friends.map(f => api.otherUser(f, userId)).filter(p => p && !members.some(m => m.id === p.id))

  return (
    <div className="picker picker--wide">
      <div className="picker-title">{eventId ? 'shared with' : 'share this memory'}</div>
      {!eventId && (
        <label className="picker-stack">
          <span>what's this memory about?</span>
          <input className="picker-input picker-input--full" placeholder="e.g. mom's 60th birthday" value={title}
            onChange={e => setTitle(e.target.value)} />
        </label>
      )}
      {members.length > 0 && (
        <div className="chip-row">{members.map(m => <span key={m.id} className="chip chip--static">{api.handle(m)}</span>)}</div>
      )}
      <div className="handle-row">
        <span className="handle-at">@</span>
        <input className="picker-input picker-input--full" placeholder="add by handle" value={handleText}
          onChange={e => { setHandleText(e.target.value); setStatus('') }}
          onKeyDown={e => e.key === 'Enter' && addByHandle()} />
        <button className="btn-small" onClick={addByHandle} disabled={busy || !handleText.trim() || !canInvite}>
          {busy ? '…' : 'add'}
        </button>
      </div>
      {!eventId && !title.trim() && <p className="picker-hint">give this memory a title before sharing</p>}
      {status && <p className="picker-hint picker-hint--warn">{status}</p>}
      {uninvited.length > 0 && (
        <div className="chip-row">
          {uninvited.map(p => (
            <button key={p.id} className="chip" disabled={!canInvite || busy} onClick={() => invite(p)}>{api.handle(p)} +</button>
          ))}
        </div>
      )}
    </div>
  )
}

export default function NoteEditor({ userId, note, onDone }) {
  const [draft, setDraft] = useState(note)
  const [open, setOpen] = useState(null) // 'date' | 'place' | 'share'
  const [error, setError] = useState('')
  const saved = useRef(note)
  const timer = useRef(null)

  const save = useCallback(async next => {
    const prev = saved.current
    const fields = ['content', 'year', 'month', 'day', 'place', 'collective_event_id']
    if (fields.every(f => (prev[f] ?? null) === (next[f] ?? null))) return
    try {
      await api.updateNote(next)
      saved.current = next
      setError('')
    } catch (e) {
      setError(e.message)
    }
  }, [])

  const draftRef = useRef(note)
  const update = patch => {
    const next = { ...draftRef.current, ...patch }
    draftRef.current = next
    setDraft(next)
    clearTimeout(timer.current)
    timer.current = setTimeout(() => save(next), 1000)
  }

  useEffect(() => () => clearTimeout(timer.current), [])

  const remove = async () => {
    clearTimeout(timer.current)
    try {
      await api.deleteNote(note.id)
      onDone()
    } catch (e) {
      setError(e.message)
    }
  }

  // Leaving an empty note discards it, like the Mac app.
  const back = async () => {
    clearTimeout(timer.current)
    if (!draft.content.trim()) return remove()
    await save(draft)
    onDone()
  }

  const close = useCallback(() => setOpen(null), [])
  const dateLabel = displayDate(draft.year, draft.month, draft.day) ?? 'set date'
  const dateStr = draft.year && draft.month && draft.day
    ? `${draft.year}-${String(draft.month).padStart(2, '0')}-${String(draft.day).padStart(2, '0')}`
    : null

  return (
    <div className="page page--editor">
      <div className="editor-bar">
        <button className="btn-back" onClick={back}>‹ memories</button>
        <div className="editor-tools">
          <div className="popover-anchor">
            <button className="tool-pill" onClick={() => setOpen(open === 'date' ? null : 'date')}>{dateLabel}</button>
            <Popover open={open === 'date'} onClose={close}>
              <DatePicker year={draft.year} month={draft.month} day={draft.day} onChange={update} />
            </Popover>
          </div>
          <div className="popover-anchor">
            <button className="tool-pill" onClick={() => setOpen(open === 'place' ? null : 'place')}>{draft.place ?? 'set place'}</button>
            <Popover open={open === 'place'} onClose={close}>
              <PlacePicker place={draft.place} onChange={place => update({ place })} />
            </Popover>
          </div>
          <div className="popover-anchor">
            <button className={`tool-pill${draft.collective_event_id ? ' tool-pill--shared' : ''}`}
              onClick={() => setOpen(open === 'share' ? null : 'share')}>
              {draft.collective_event_id ? '👥 shared' : '👥 @'}
            </button>
            <Popover open={open === 'share'} onClose={close} align="right">
              <SharePanel userId={userId} note={draft} content={draft.content} dateStr={dateStr}
                eventId={draft.collective_event_id}
                onShared={id => {
                  // shareNote already linked the note server-side; keep local state in step.
                  draftRef.current = { ...draftRef.current, collective_event_id: id }
                  setDraft(draftRef.current)
                  saved.current = { ...saved.current, collective_event_id: id }
                }} />
            </Popover>
          </div>
        </div>
        <button className="icon-btn icon-btn--danger" onClick={remove} aria-label="delete memory">🗑</button>
      </div>
      {error && <div className="form-error">{error}</div>}
      <textarea
        className="editor-textarea"
        value={draft.content}
        onChange={e => update({ content: e.target.value })}
        placeholder="write a memory, a thought, anything…"
        autoFocus
      />
    </div>
  )
}
