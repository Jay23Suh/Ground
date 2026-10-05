import { useState } from 'react'
import { ReactComponent as LegoIcon } from '../lego.svg'
import { categoryLabel } from '../lib/stats'

const CHAR_LIMIT = 2000

export default function JournalPopup({ question, category, onSave, onSkip, onClose }) {
  const [answer, setAnswer] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const trimmed = answer.trim()

  const run = async action => {
    setSaving(true)
    setError('')
    try {
      await action()
    } catch (e) {
      setError(e.message)
      setSaving(false)
    }
  }

  const save = () => { if (trimmed && !saving) run(() => onSave(trimmed)) }
  const skip = () => { if (!saving) run(onSkip) }

  const onKeyDown = e => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); save() }
    if (e.key === 'Escape') onClose()
  }

  return (
    <div className="popup-overlay" onKeyDown={onKeyDown}>
      <div className="popup" role="dialog" aria-modal="true" aria-label="journal prompt">
        <div className="popup-top">
          <span className="popup-brand"><LegoIcon style={{ width: 12, height: 12 }} /> ground</span>
          <span className="popup-category">{categoryLabel(category)}</span>
          <button className="popup-close" onClick={onClose} aria-label="close">×</button>
        </div>
        <div className="popup-question">{question}</div>
        <textarea
          className="popup-textarea"
          placeholder="write freely..."
          value={answer}
          maxLength={CHAR_LIMIT}
          onChange={e => setAnswer(e.target.value)}
          autoFocus
        />
        {answer.length > CHAR_LIMIT - 200 && (
          <div className={`popup-count${answer.length > CHAR_LIMIT - 50 ? ' popup-count--warn' : ''}`}>
            {CHAR_LIMIT - answer.length} left
          </div>
        )}
        {error && <div className="form-error">{error}</div>}
        <div className="popup-btns">
          <button className="btn-skip" onClick={skip} disabled={saving}>skip</button>
          <button className="btn-save" onClick={save} disabled={!trimmed || saving}>
            {saving ? '...' : 'save ⌘↵'}
          </button>
        </div>
      </div>
    </div>
  )
}
