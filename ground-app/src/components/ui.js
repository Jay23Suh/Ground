import { useEffect, useRef } from 'react'
import { categoryLabel, formatEntryDate } from '../lib/stats'

export function SearchBar({ value, onChange, placeholder }) {
  return (
    <div className="search-bar">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
      <input value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} aria-label={placeholder} />
      {value && <button className="search-clear" onClick={() => onChange('')} aria-label="clear search">×</button>}
    </div>
  )
}

export function FilterPills({ options, selected, onSelect, allLabel = 'all' }) {
  return (
    <div className="category-filters">
      <button className={`category-pill${selected == null ? ' active' : ''}`} onClick={() => onSelect(null)}>{allLabel}</button>
      {options.map(o => (
        <button key={o.value} className={`category-pill${selected === o.value ? ' active' : ''}`}
          onClick={() => onSelect(selected === o.value ? null : o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  )
}

// Small anchored panel that closes on outside click or Escape.
export function Popover({ open, onClose, children, align = 'left' }) {
  const ref = useRef(null)
  useEffect(() => {
    if (!open) return undefined
    const onDown = e => { if (ref.current && !ref.current.contains(e.target)) onClose() }
    const onKey = e => { if (e.key === 'Escape') onClose() }
    document.addEventListener('mousedown', onDown)
    document.addEventListener('keydown', onKey)
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey) }
  }, [open, onClose])
  if (!open) return null
  return <div ref={ref} className={`popover popover--${align}`}>{children}</div>
}

export function EntryCard({ entry, highlighted, showCategory = true }) {
  return (
    <div className={`entry-card${highlighted ? ' entry-card--highlight' : ''}`} id={`entry-${entry.id}`}>
      <div className="entry-meta">
        {showCategory && entry.category && (
          <span className={`entry-category entry-category--${entry.category}`}>{categoryLabel(entry.category)}</span>
        )}
        <span className="entry-date">{formatEntryDate(entry.created_at)}</span>
        {entry.skipped && <span className="entry-skipped">skipped</span>}
      </div>
      {entry.question && <div className="entry-q">{entry.question}</div>}
      {!entry.skipped && entry.answer && <div className="entry-a">{entry.answer}</div>}
    </div>
  )
}
