import { localDateString, readJSON, writeJSON } from '../lib/storage'

const FALLBACK_QUOTE = { q: 'Stay grounded.', a: 'Ground' }
const ZEN_QUOTES_API = 'https://zenquotes.io/api/today'
const CACHE_KEY = 'ground_quote_cache'
const SHOWN_KEY = 'ground_quote_last_shown'

export const QuoteService = {
  async getQuoteOfTheDay() {
    const today = localDateString()
    const cached = readJSON(CACHE_KEY, null)
    if (cached?.date === today) return cached.quote

    try {
      const data = await (await fetch(ZEN_QUOTES_API)).json()
      if (data?.[0]?.q) {
        const quote = { q: data[0].q, a: data[0].a }
        writeJSON(CACHE_KEY, { date: today, quote })
        return quote
      }
    } catch {
      // API down — fall through
    }
    // A stale quote beats the generic fallback.
    return cached?.quote ?? FALLBACK_QUOTE
  },

  // The daily quote modal appears once per day, after the user's configured start time.
  shouldShowModal(startTime = '08:00') {
    if (readJSON(SHOWN_KEY, null) === localDateString()) return false
    const [h, m] = startTime.split(':').map(Number)
    const now = new Date()
    return now.getHours() * 60 + now.getMinutes() >= (h || 0) * 60 + (m || 0)
  },

  markQuoteAsShown() {
    writeJSON(SHOWN_KEY, localDateString())
  },
}
