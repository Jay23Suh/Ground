import React from 'react'
import './QuoteComponents.css'

const QuoteModal = ({ quote, onDismiss }) => {
  if (!quote) return null

  return (
    <div className="quote-modal-overlay" onClick={onDismiss}>
      <div className="quote-modal-card" onClick={e => e.stopPropagation()}>
        <span className="quote-modal-icon">✦</span>
        <p className="quote-modal-text">"{quote.q}"</p>
        <p className="quote-modal-author">— {quote.a}</p>
      </div>
    </div>
  )
}

export default QuoteModal
