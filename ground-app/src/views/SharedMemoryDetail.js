import { useCallback, useEffect, useRef, useState } from 'react'
import * as api from '../lib/api'
import { getCollectivePlaces, setCollectivePlace } from '../lib/storage'
import { Popover } from '../components/ui'
import { PlacePicker } from './NoteEditor'

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

function eventDisplayDate(ds) {
  const [y, m, d] = (ds || '').split('-').map(Number)
  return y && m >= 1 && m <= 12 && d ? `${MONTHS[m - 1]} ${d}, ${y}` : null
}

function PerspectiveMenu({ userId, perspective, onBlocked }) {
  const [open, setOpen] = useState(false)
  const [done, setDone] = useState('')
  const close = useCallback(() => setOpen(false), [])
  const name = api.handle(perspective.author)

  const act = async (fn, msg) => {
    try { await fn(); setDone(msg) } catch (e) { setDone(e.message) }
    setOpen(false)
  }

  return (
    <div className="popover-anchor">
      <button className="icon-btn icon-btn--plain" onClick={() => setOpen(o => !o)} aria-label="more options">⋯</button>
      <Popover open={open} onClose={close} align="right">
        <div className="menu">
          <button className="menu-item menu-item--danger"
            onClick={() => act(() => api.reportContent(userId, perspective.user_id, 'perspective', perspective.id), 'reported — thank you')}>
            report this perspective
          </button>
          <button className="menu-item menu-item--danger"
            onClick={() => act(async () => { await api.blockUser(userId, perspective.user_id); onBlocked(perspective.user_id) }, `blocked ${name}`)}>
            block {name}
          </button>
        </div>
      </Popover>
      {done && <span className="menu-status">{done}</span>}
    </div>
  )
}

export default function SharedMemoryDetail({ userId, event, onBack, onPlaceChange }) {
  const [perspectives, setPerspectives] = useState([])
  const [content, setContent] = useState('')
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [placeOpen, setPlaceOpen] = useState(false)
  const [place, setPlace] = useState(() => getCollectivePlaces()[event.id] ?? null)
  const [blocked, setBlocked] = useState([])
  const timer = useRef(null)
  const contentRef = useRef('')

  useEffect(() => {
    let cancelled = false
    api.fetchCollectivePerspectives([event.id]).then(all => {
      if (cancelled) return
      setPerspectives(all)
      const mine = all.find(p => p.user_id === userId)
      if (mine) {
        setContent(mine.content)
        contentRef.current = mine.content
        setSubmitted(mine.submitted)
      }
      setLoading(false)
    }).catch(e => { if (!cancelled) { setError(e.message); setLoading(false) } })
    return () => { cancelled = true; clearTimeout(timer.current) }
  }, [event.id, userId])

  const saveDraft = useCallback(async () => {
    try {
      await api.saveCollectivePerspective(userId, event.id, contentRef.current, false)
    } catch (e) {
      setError(e.message)
    }
  }, [userId, event.id])

  const onChange = value => {
    setContent(value)
    contentRef.current = value
    clearTimeout(timer.current)
    timer.current = setTimeout(saveDraft, 1500)
  }

  const submit = async () => {
    if (!content.trim()) return
    clearTimeout(timer.current)
    setSaving(true)
    setError('')
    try {
      await api.saveCollectivePerspective(userId, event.id, content, true)
      setSubmitted(true)
      setPerspectives(await api.fetchCollectivePerspectives([event.id]))
    } catch (e) {
      setError(e.message)
    }
    setSaving(false)
  }

  const back = async () => {
    clearTimeout(timer.current)
    if (!submitted && !loading) await saveDraft()
    onBack()
  }

  const changePlace = p => {
    setCollectivePlace(event.id, p)
    setPlace(p)
    onPlaceChange()
  }

  const submittedCount = perspectives.filter(p => p.submitted).length
  const others = submitted
    ? perspectives.filter(p => p.user_id !== userId && p.submitted && !blocked.includes(p.user_id))
    : []
  const date = eventDisplayDate(event.event_date)

  return (
    <div className="page page--editor">
      <div className="editor-bar">
        <button className="btn-back" onClick={back}>‹ memories</button>
        {submittedCount > 0 && <span className="wrote-count">👥 {submittedCount} wrote</span>}
      </div>

      {loading ? (
        <div className="empty-state"><div className="loading-dot" /></div>
      ) : (
        <>
          <h1 className="shared-title">{event.title}</h1>
          <div className="shared-meta">
            {date && <span>{date}</span>}
            <div className="popover-anchor">
              <button className="tool-pill" onClick={() => setPlaceOpen(o => !o)}>{place ?? 'set place'}</button>
              <Popover open={placeOpen} onClose={() => setPlaceOpen(false)}>
                <PlacePicker place={place} onChange={changePlace} />
              </Popover>
            </div>
          </div>

          <div className="shared-write">
            <div className="shared-write-head">
              <span className="section-label" style={{ margin: 0 }}>{submitted ? 'your memory' : 'what do you remember?'}</span>
              {submitted && <button className="btn-link" onClick={() => setSubmitted(false)}>edit</button>}
            </div>
            <textarea className="editor-textarea editor-textarea--boxed" value={content} disabled={submitted}
              onChange={e => onChange(e.target.value)} autoFocus={!submitted} />
            {error && <div className="form-error">{error}</div>}
            {!submitted && (
              <>
                <button className="btn-submit" onClick={submit} disabled={!content.trim() || saving}>
                  {saving ? '…' : 'submit'}
                </button>
                <p className="picker-hint">once you submit, you'll see what others remember</p>
              </>
            )}
          </div>

          {submitted && (others.length === 0 ? (
            <p className="empty-hint" style={{ marginTop: 24 }}>waiting for others to write their memories…</p>
          ) : (
            <div className="others">
              <h2 className="section-label">others remember</h2>
              {others.map(p => (
                <div className="perspective" key={p.id}>
                  <div className="perspective-head">
                    <span className="perspective-author">{api.handle(p.author)}</span>
                    <PerspectiveMenu userId={userId} perspective={p} onBlocked={id => setBlocked(b => [...b, id])} />
                  </div>
                  <p className="perspective-body">{p.content}</p>
                </div>
              ))}
            </div>
          ))}
        </>
      )}
    </div>
  )
}
