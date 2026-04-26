import React from 'react';
import './QuoteComponents.css';

const QuoteBanner = ({ quote }) => {
  if (!quote) return null;

  return (
    <div className="quote-banner">
      <div className="quote-banner-content">
        <p className="quote-banner-text">"{quote.q}"</p>
        <p className="quote-banner-author">— {quote.a}</p>
      </div>
    </div>
  );
};

export default QuoteBanner;
