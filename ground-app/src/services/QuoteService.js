const FALLBACK_QUOTE = { q: "Stay grounded.", a: "Ground" }
const ZEN_QUOTES_API = 'https://zenquotes.io/api/today'

export const QuoteService = {
  async getQuoteOfTheDay() {
    const today = new Date().toISOString().split('T')[0]
    const cached = localStorage.getItem('ground_quote_cache')

    if (cached) {
      const { date, quote } = JSON.parse(cached)
      if (date === today) return quote
    }

    try {
      const response = await fetch(ZEN_QUOTES_API)
      const data = await response.json()
      if (data && data[0]) {
        const quote = { q: data[0].q, a: data[0].a }
        localStorage.setItem('ground_quote_cache', JSON.stringify({ date: today, quote }))
        return quote
      }
    } catch {
      // API down — use fallback
    }

    return FALLBACK_QUOTE
  },

  shouldShowModal(profile) {
    if (!profile) return false

    const { quote_start_time, last_quote_shown_at } = profile
    const now = new Date()
    const [hours, minutes] = (quote_start_time || '06:00:00').split(':').map(Number)

    let referencePoint = new Date()
    referencePoint.setHours(hours, minutes, 0, 0)
    if (now < referencePoint) referencePoint.setDate(referencePoint.getDate() - 1)

    if (!last_quote_shown_at) return true
    return new Date(last_quote_shown_at) < referencePoint
  },

  async markQuoteAsShown(supabase, userId) {
    await supabase
      .from('profiles')
      .update({ last_quote_shown_at: new Date().toISOString() })
      .eq('id', userId)
  },
}
