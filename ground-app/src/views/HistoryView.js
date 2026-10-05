import { useEffect, useMemo, useState } from 'react'
import { SearchBar, FilterPills, EntryCard } from '../components/ui'
import { categoryLabel } from '../lib/stats'

export default function HistoryView({ entries, scrollTarget, onScrolled }) {
  const [category, setCategory] = useState(null)
  const [search, setSearch] = useState('')
  const [highlighted, setHighlighted] = useState(null)

  const categories = useMemo(
    () => [...new Set(entries.map(e => e.category).filter(Boolean))].sort()
      .map(c => ({ value: c, label: categoryLabel(c) })),
    [entries],
  )

  const filtered = useMemo(() => {
    let result = category ? entries.filter(e => e.category === category) : entries
    const q = search.trim().toLowerCase()
    if (q) {
      result = result.filter(e =>
        (e.answer || '').toLowerCase().includes(q) || categoryLabel(e.category).toLowerCase().includes(q))
    }
    return result
  }, [entries, category, search])

  // Jump to an entry picked from stats: clear filters, scroll, flash a highlight.
  useEffect(() => {
    if (!scrollTarget) return undefined
    setCategory(null)
    setSearch('')
    const t1 = setTimeout(() => {
      document.getElementById(`entry-${scrollTarget}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      setHighlighted(scrollTarget)
      onScrolled()
    }, 100)
    const t2 = setTimeout(() => setHighlighted(null), 1800)
    return () => { clearTimeout(t1); clearTimeout(t2) }
  }, [scrollTarget, onScrolled])

  return (
    <div className="page">
      <h1 className="page-title">history</h1>
      <SearchBar value={search} onChange={setSearch} placeholder="search entries..." />
      {categories.length > 0 && <FilterPills options={categories} selected={category} onSelect={setCategory} />}
      {filtered.length === 0 ? (
        <div className="empty-state">
          <p className="empty">{search ? 'no results' : 'no entries yet — write your first one!'}</p>
          {search && <p className="empty-hint">try a different keyword or category</p>}
        </div>
      ) : (
        <div className="entries-list">
          {filtered.map(e => <EntryCard key={e.id} entry={e} highlighted={e.id === highlighted} />)}
        </div>
      )}
    </div>
  )
}
