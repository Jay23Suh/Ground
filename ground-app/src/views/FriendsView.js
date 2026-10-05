import { useCallback, useEffect, useState } from 'react'
import * as api from '../lib/api'
import { Popover } from '../components/ui'

function FriendMenu({ onRemove, onBlock, onReport, name }) {
  const [open, setOpen] = useState(false)
  const close = useCallback(() => setOpen(false), [])
  const pick = fn => () => { setOpen(false); fn() }
  return (
    <div className="popover-anchor">
      <button className="icon-btn icon-btn--plain" onClick={() => setOpen(o => !o)} aria-label={`options for ${name}`}>⋯</button>
      <Popover open={open} onClose={close} align="right">
        <div className="menu">
          <button className="menu-item menu-item--danger" onClick={pick(onRemove)}>remove friend</button>
          <button className="menu-item menu-item--danger" onClick={pick(onBlock)}>block {name}</button>
          <button className="menu-item menu-item--danger" onClick={pick(onReport)}>report {name}</button>
        </div>
      </Popover>
    </div>
  )
}

export default function FriendsView({ userId, onBack, onUsernameChange }) {
  const [username, setUsername] = useState(null)
  const [usernameInput, setUsernameInput] = useState('')
  const [usernameStatus, setUsernameStatus] = useState(null)
  const [query, setQuery] = useState('')
  const [result, setResult] = useState(null)
  const [searchStatus, setSearchStatus] = useState(null)
  const [friends, setFriends] = useState([])
  const [pending, setPending] = useState([])
  const [loading, setLoading] = useState(true)
  const [actionMsg, setActionMsg] = useState('')

  const loadAll = useCallback(async () => {
    setLoading(true)
    setActionMsg('')
    const [profile, f, p] = await Promise.allSettled([
      api.fetchProfile(userId), api.fetchFriends(userId), api.fetchPendingRequests(userId),
    ])
    setUsername(profile.value?.username ?? null)
    if (f.status === 'fulfilled') setFriends(f.value)
    else { setFriends([]); setActionMsg("couldn't load friends") }
    setPending(p.status === 'fulfilled' ? p.value : [])
    setLoading(false)
  }, [userId])

  useEffect(() => { loadAll() }, [loadAll])

  const lowered = usernameInput.trim().toLowerCase()

  const claim = async () => {
    if (!/^[a-z0-9_]{3,20}$/.test(lowered)) {
      setUsernameStatus({ text: '3–20 chars, letters, numbers, underscores only', warn: true })
      return
    }
    setUsernameStatus({ text: 'checking…' })
    try {
      if (await api.isUsernameTaken(userId, lowered)) {
        setUsernameStatus({ text: 'already taken — try another', warn: true })
      } else {
        await api.updateProfile(userId, { username: lowered })
        setUsername(lowered)
        setUsernameInput('')
        setUsernameStatus(null)
        onUsernameChange?.(lowered)
      }
    } catch (e) {
      setUsernameStatus({ text: e.message, warn: true })
    }
  }

  const search = async () => {
    const q = query.trim().replace(/^@/, '').toLowerCase()
    if (!q) return
    setSearchStatus('searching')
    setResult(null)
    try {
      const found = await api.searchUser(userId, q)
      if (!found) setSearchStatus('notFound')
      else if (friends.some(f => api.otherUser(f, userId).id === found.id) || pending.some(p => p.requester_id === found.id)) {
        setSearchStatus('alreadyFriends')
      } else {
        setResult(found)
        setSearchStatus('found')
      }
    } catch (e) {
      setSearchStatus(e.message)
    }
  }

  const sendRequest = async () => {
    try {
      await api.sendFriendRequest(userId, result.id)
      setSearchStatus('sent')
      setResult(null)
      setQuery('')
    } catch {
      setSearchStatus("couldn't send request")
    }
  }

  const respond = async (req, accept) => {
    try {
      await api.respondToRequest(req.id, accept)
      await loadAll()
    } catch {
      setActionMsg("couldn't respond — try again")
    }
  }

  const remove = async friendship => {
    try {
      await api.removeFriend(friendship.id)
      setFriends(fs => fs.filter(f => f.id !== friendship.id))
    } catch {
      setActionMsg("couldn't remove friend — try again")
    }
  }

  const block = async (friendship, other) => {
    try {
      await api.blockUser(userId, other.id)
      await api.removeFriend(friendship.id)
      setFriends(fs => fs.filter(f => f.id !== friendship.id))
      setActionMsg(`blocked ${api.handle(other)}`)
    } catch (e) {
      setActionMsg(e.message)
    }
  }

  const report = async other => {
    try {
      await api.reportContent(userId, other.id, 'user', null)
      setActionMsg(`reported ${api.handle(other)} — thank you`)
    } catch (e) {
      setActionMsg(e.message)
    }
  }

  const searchMessages = {
    notFound: 'no user found with that handle',
    sent: 'friend request sent',
    alreadyFriends: 'already friends',
    searching: 'searching…',
  }

  return (
    <div className="page">
      <button className="btn-back" onClick={onBack}>‹ settings</button>
      <h1 className="page-title">friends</h1>

      {loading ? <div className="empty-state"><div className="loading-dot" /></div> : (
        <>
          <section className="settings-group">
            <h2 className="settings-label">your handle</h2>
            <div className="settings-card">
              {username ? (
                <>
                  <div className="handle-big">@{username}</div>
                  <p className="settings-help">share this so friends can find you</p>
                </>
              ) : (
                <>
                  <p className="settings-help">claim your @handle so friends can find you</p>
                  <div className="handle-row">
                    <span className="handle-at">@</span>
                    <input className="settings-control settings-control--grow" value={usernameInput} placeholder="username"
                      onChange={e => { setUsernameInput(e.target.value); setUsernameStatus(null) }}
                      onKeyDown={e => e.key === 'Enter' && claim()} />
                    <button className="btn-small" onClick={claim} disabled={!lowered}>claim</button>
                  </div>
                  {usernameStatus
                    ? <p className={`picker-hint${usernameStatus.warn ? ' picker-hint--warn' : ''}`}>{usernameStatus.text}</p>
                    : lowered && lowered !== usernameInput.trim() && <p className="picker-hint">will be saved as @{lowered}</p>}
                </>
              )}
            </div>
          </section>

          <section className="settings-group">
            <h2 className="settings-label">add a friend</h2>
            <div className="settings-card">
              <div className="handle-row">
                <span className="handle-at">@</span>
                <input className="settings-control settings-control--grow" value={query} placeholder="their handle"
                  onChange={e => { setQuery(e.target.value); setSearchStatus(null); setResult(null) }}
                  onKeyDown={e => e.key === 'Enter' && search()} />
                <button className="btn-small" onClick={search} disabled={!query.trim()}>find</button>
              </div>
              {result && (
                <div className="friend-row">
                  <span>{api.handle(result)}</span>
                  <button className="btn-small" onClick={sendRequest}>send request</button>
                </div>
              )}
              {searchStatus && searchStatus !== 'found' && (
                <p className={`picker-hint${searchStatus === 'sent' ? ' picker-hint--ok' : ''}`}>
                  {searchMessages[searchStatus] ?? searchStatus}
                </p>
              )}
            </div>
          </section>

          {pending.length > 0 && (
            <section className="settings-group">
              <h2 className="settings-label">requests</h2>
              <div className="settings-card">
                {pending.map(req => (
                  <div className="friend-row" key={req.id}>
                    <span>{api.handle(req.requester)}</span>
                    <span className="friend-actions">
                      <button className="btn-small btn-small--ghost" onClick={() => respond(req, false)}>decline</button>
                      <button className="btn-small" onClick={() => respond(req, true)}>accept</button>
                    </span>
                  </div>
                ))}
              </div>
            </section>
          )}

          <section className="settings-group">
            <h2 className="settings-label">friends</h2>
            <div className="settings-card">
              {friends.length === 0 ? <p className="settings-help">add a friend above to get started</p> : friends.map(f => {
                const other = api.otherUser(f, userId)
                return (
                  <div className="friend-row" key={f.id}>
                    <span>{api.handle(other)}</span>
                    <FriendMenu name={api.handle(other)}
                      onRemove={() => remove(f)} onBlock={() => block(f, other)} onReport={() => report(other)} />
                  </div>
                )
              })}
            </div>
            {actionMsg && <p className="picker-hint">{actionMsg}</p>}
          </section>
        </>
      )}
    </div>
  )
}
