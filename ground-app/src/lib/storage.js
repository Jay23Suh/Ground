// localStorage wrappers — storage can be unavailable (private mode, blocked
// site data), so every read/write is guarded and falls back to a default.

export function readJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key)
    return raw == null ? fallback : JSON.parse(raw)
  } catch {
    return fallback
  }
}

export function writeJSON(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)) } catch {}
}

export function localDateString(d = new Date()) {
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

// ── Popup interval (minutes) ─────────────────────────────────────────────────
const INTERVAL_KEY = 'ground_popup_interval_minutes'
export const MIN_INTERVAL = 20
export const MAX_INTERVAL = 1440
export const DEFAULT_INTERVAL = 120

export function getPopupInterval() {
  const v = Number(readJSON(INTERVAL_KEY, DEFAULT_INTERVAL))
  return Number.isFinite(v) ? Math.min(Math.max(v, MIN_INTERVAL), MAX_INTERVAL) : DEFAULT_INTERVAL
}

export function setPopupInterval(minutes) {
  writeJSON(INTERVAL_KEY, Math.min(Math.max(minutes, MIN_INTERVAL), MAX_INTERVAL))
}

// ── Shared memories: per-device "seen" timestamps and private place tags ─────
// Place for a shared memory is local-only and never synced: each member can tag
// the same shared memory with their own place without disclosing it to others.
const SEEN_KEY = 'ground_collective_seen_at'
const PLACES_KEY = 'ground_collective_local_places'
const LAST_CHECK_KEY = 'ground_collective_last_check'
const RECENT_PLACES_KEY = 'ground_recent_places'

export const getCollectiveSeenAt = () => readJSON(SEEN_KEY, {})
export function markCollectiveSeen(eventId) {
  const seen = getCollectiveSeenAt()
  seen[eventId] = Date.now()
  writeJSON(SEEN_KEY, seen)
}

export const getCollectivePlaces = () => readJSON(PLACES_KEY, {})
export function setCollectivePlace(eventId, place) {
  const places = getCollectivePlaces()
  if (place) places[eventId] = place
  else delete places[eventId]
  writeJSON(PLACES_KEY, places)
}

export const getCollectiveLastCheck = () => readJSON(LAST_CHECK_KEY, 0)
export const setCollectiveLastCheck = ts => writeJSON(LAST_CHECK_KEY, ts)

export const getRecentPlaces = () => readJSON(RECENT_PLACES_KEY, [])
export function pushRecentPlace(place) {
  const recent = getRecentPlaces().filter(p => p !== place)
  recent.unshift(place)
  writeJSON(RECENT_PLACES_KEY, recent.slice(0, 8))
}
