// Data layer — mirrors Ground/Ground/SupabaseManager.swift so web and Mac read
// and write the same rows. Every function throws on a Supabase error.
import { supabase, supabaseConfigError } from '../supabase'

function db() {
  if (!supabase) throw new Error(supabaseConfigError)
  return supabase
}

async function run(query) {
  const { data, error } = await query
  if (error) throw error
  return data
}

const nowISO = () => new Date().toISOString()

// notes.user_id is a text column, and older Mac builds wrote it with Swift's
// uppercase uuidString while Supabase ids are lowercase — read both casings.
const ownerIds = uid => [...new Set([uid, uid.toLowerCase(), uid.toUpperCase()])]

// ── Account ──────────────────────────────────────────────────────────────────
export const updatePassword = password => run(db().auth.updateUser({ password }))
export const signOut = () => run(db().auth.signOut())

export async function deleteAccount() {
  await run(db().rpc('delete_account'))
  await db().auth.signOut()
}

export const reportContent = (uid, reportedUserId, contentType, contentId) =>
  run(db().from('reports').insert({
    reporter_id: uid, reported_user_id: reportedUserId,
    content_type: contentType, content_id: contentId ?? null,
  }))

export const blockUser = (uid, blockedId) =>
  run(db().from('blocks').insert({ blocker_id: uid, blocked_id: blockedId }))

// ── Journal entries ──────────────────────────────────────────────────────────
export const fetchEntries = uid =>
  run(db().from('journal_entries').select('*').eq('user_id', uid).order('created_at', { ascending: false }))

const touchActivity = uid =>
  run(db().from('activity_tracker').upsert({ user_id: uid, last_popup_shown: nowISO() }, { onConflict: 'user_id' }))

export async function saveEntry(uid, question, category, answer) {
  await run(db().from('journal_entries').insert({ user_id: uid, question, category, answer, skipped: false }))
  await touchActivity(uid)
}

export async function saveSkip(uid, question, category) {
  await run(db().from('journal_entries').insert({ user_id: uid, question, category, answer: '', skipped: true }))
  await touchActivity(uid)
}

export async function fetchLastPopup(uid) {
  const row = await run(db().from('activity_tracker').select('last_popup_shown').eq('user_id', uid).maybeSingle())
  return row?.last_popup_shown ?? null
}

export const startActivity = touchActivity

// ── Profile ──────────────────────────────────────────────────────────────────
export const fetchProfile = uid =>
  run(db().from('profiles').select('*').eq('id', uid).maybeSingle())

export const updateProfile = (uid, updates) =>
  run(db().from('profiles').update(updates).eq('id', uid))

export async function isUsernameTaken(uid, username) {
  const rows = await run(db().from('profiles').select('id').eq('username', username).neq('id', uid).limit(1))
  return rows.length > 0
}

export async function searchUser(uid, username) {
  const rows = await run(db().from('profiles').select('id, username')
    .eq('username', username.toLowerCase()).neq('id', uid).limit(1))
  return rows[0] ?? null
}

// ── Friends ──────────────────────────────────────────────────────────────────
export const sendFriendRequest = (uid, userId) =>
  run(db().from('friendships').insert({ requester_id: uid, addressee_id: userId }))

export const fetchFriends = uid =>
  run(db().from('friendships')
    .select('id, requester_id, addressee_id, status, requester:profiles!requester_id(id, username), addressee:profiles!addressee_id(id, username)')
    .or(`requester_id.eq.${uid},addressee_id.eq.${uid}`)
    .eq('status', 'accepted'))

export const fetchPendingRequests = uid =>
  run(db().from('friendships')
    .select('id, requester_id, requester:profiles!requester_id(id, username)')
    .eq('addressee_id', uid)
    .eq('status', 'pending'))

export const respondToRequest = (id, accept) => accept
  ? run(db().from('friendships').update({ status: 'accepted' }).eq('id', id))
  : run(db().from('friendships').delete().eq('id', id))

export const removeFriend = id => run(db().from('friendships').delete().eq('id', id))

export const otherUser = (friendship, uid) =>
  friendship.requester_id === uid ? friendship.addressee : friendship.requester

export const handle = profile => `@${profile?.username ?? 'unknown'}`

// ── Notes (memories) ─────────────────────────────────────────────────────────
export const fetchNotes = uid =>
  run(db().from('notes').select('*').in('user_id', ownerIds(uid)).order('created_at', { ascending: false }))

export async function createNote(uid) {
  const now = nowISO()
  const note = {
    id: crypto.randomUUID(), user_id: uid, content: '',
    year: null, month: null, day: null, place: null, collective_event_id: null,
    created_at: now, updated_at: now,
  }
  await run(db().from('notes').insert({
    id: note.id, user_id: uid, content: '', created_at: now, updated_at: now,
  }))
  return note
}

export const updateNote = note =>
  run(db().from('notes').update({
    content: note.content, year: note.year, month: note.month, day: note.day,
    place: note.place, collective_event_id: note.collective_event_id,
    updated_at: nowISO(),
  }).eq('id', note.id))

export const deleteNote = id => run(db().from('notes').delete().eq('id', id))

// ── Shared memories ──────────────────────────────────────────────────────────
// Creates the shared memory on first invite (event + self membership + links the
// note + seeds the sharer's perspective), then adds the invitee.
export async function shareNote(uid, { noteId, noteContent, title, noteDateStr, existingEventId, addUserId }) {
  let eventId = existingEventId
  if (!eventId) {
    eventId = crypto.randomUUID()
    const now = nowISO()
    await run(db().from('collective_events').insert({
      id: eventId, title, event_date: noteDateStr, created_by: uid, created_at: now,
    }))
    await run(db().from('collective_members').insert({ event_id: eventId, user_id: uid, invited_by: uid }))
    await run(db().from('notes').update({ collective_event_id: eventId }).eq('id', noteId))
    await run(db().from('collective_perspectives').upsert({
      event_id: eventId, user_id: uid, content: noteContent, submitted: true, updated_at: now,
    }, { onConflict: 'event_id,user_id' }))
  }
  await run(db().from('collective_members').insert({ event_id: eventId, user_id: addUserId, invited_by: uid }))
  return eventId
}

export async function fetchCollectiveEvents(uid) {
  const rows = await run(db().from('collective_members').select('event_id').eq('user_id', uid))
  if (!rows.length) return []
  return run(db().from('collective_events').select('*')
    .in('id', rows.map(r => r.event_id))
    .order('created_at', { ascending: false }))
}

export function fetchCollectivePerspectives(eventIds) {
  if (!eventIds.length) return Promise.resolve([])
  return run(db().from('collective_perspectives')
    .select('id, event_id, user_id, content, submitted, updated_at, author:profiles!user_id(id, username)')
    .in('event_id', eventIds))
}

export async function fetchEventMembers(eventId) {
  const rows = await run(db().from('collective_members')
    .select('profile:profiles!user_id(id, username)')
    .eq('event_id', eventId))
  return rows.map(r => r.profile).filter(Boolean)
}

export const saveCollectivePerspective = (uid, eventId, content, submitted) =>
  run(db().from('collective_perspectives').upsert({
    event_id: eventId, user_id: uid, content, submitted, updated_at: nowISO(),
  }, { onConflict: 'event_id,user_id' }))
