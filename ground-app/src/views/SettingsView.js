import { useEffect, useState } from 'react'
import * as api from '../lib/api'
import { getPopupInterval, setPopupInterval, MIN_INTERVAL, MAX_INTERVAL } from '../lib/storage'
import FriendsView from './FriendsView'

const PRIVACY_URL = 'https://github.com/Jay23Suh/Ground/blob/main/Ground/PRIVACY_POLICY.md'
const TERMS_URL = 'https://github.com/Jay23Suh/Ground/blob/main/Ground/TERMS_OF_SERVICE.md'

function formatInterval(m) {
  if (m < 60) return `${m} min`
  const h = Math.floor(m / 60), rem = m % 60
  return rem ? `${h}h ${rem}m` : `${h}h`
}

function notificationState() {
  if (!('Notification' in window)) return 'unsupported'
  return Notification.permission
}

export default function SettingsView({ session, profile, onProfileChange, onIntervalChange }) {
  const userId = session.user.id
  const [showFriends, setShowFriends] = useState(false)
  const [startTime, setStartTime] = useState((profile?.quote_start_time || '08:00:00').slice(0, 5))
  const [interval, setIntervalState] = useState(getPopupInterval)
  const [minutesText, setMinutesText] = useState(String(getPopupInterval()))
  const [notif, setNotif] = useState(notificationState)
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [pwStatus, setPwStatus] = useState(null)
  const [savingPw, setSavingPw] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (profile?.quote_start_time) setStartTime(profile.quote_start_time.slice(0, 5))
  }, [profile?.quote_start_time])

  const changeStartTime = async value => {
    setStartTime(value)
    try {
      await api.updateProfile(userId, { quote_start_time: `${value}:00` })
      onProfileChange()
    } catch (e) {
      setError(e.message)
    }
  }

  const changeInterval = minutes => {
    const clamped = Math.min(Math.max(Math.round(minutes), MIN_INTERVAL), MAX_INTERVAL)
    setIntervalState(clamped)
    setMinutesText(String(clamped))
    setPopupInterval(clamped)
    onIntervalChange()
  }

  const enableNotifications = async () => {
    if (notif === 'default') setNotif(await Notification.requestPermission())
  }

  const changePassword = async () => {
    if (newPassword !== confirmPassword) { setPwStatus({ text: "passwords don't match", warn: true }); return }
    if (newPassword.length < 6) { setPwStatus({ text: 'password must be at least 6 characters', warn: true }); return }
    setSavingPw(true)
    try {
      await api.updatePassword(newPassword)
      setPwStatus({ text: 'password updated' })
      setNewPassword('')
      setConfirmPassword('')
    } catch (e) {
      setPwStatus({ text: e.message, warn: true })
    }
    setSavingPw(false)
  }

  const deleteAccount = async () => {
    setDeleting(true)
    try {
      await api.deleteAccount()
    } catch {
      setError('deletion failed — contact support')
      setDeleting(false)
    }
  }

  if (showFriends) {
    return <FriendsView userId={userId} onBack={() => setShowFriends(false)} onUsernameChange={onProfileChange} />
  }

  const notifLabel = {
    granted: 'enabled while ground is open in a tab',
    denied: 'blocked — allow notifications for this site in your browser settings',
    default: 'not set up yet',
    unsupported: "this browser doesn't support notifications",
  }[notif]

  return (
    <div className="page">
      <h1 className="page-title">settings</h1>
      {error && <div className="form-error">{error}</div>}

      <section className="settings-group">
        <h2 className="settings-label">daily grounding</h2>
        <div className="settings-card">
          <label className="settings-row">
            <span>start each day at</span>
            <input type="time" className="settings-control" value={startTime} onChange={e => changeStartTime(e.target.value)} />
          </label>
          <p className="settings-help">this controls when your daily quote resets and the grounding modal appears.</p>
        </div>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">check-in frequency</h2>
        <div className="settings-card">
          <div className="settings-row">
            <span>popup appears every</span>
            <strong className="settings-value">{formatInterval(interval)}</strong>
          </div>
          <input type="range" className="settings-range" min={MIN_INTERVAL} max={MAX_INTERVAL} step={5}
            value={interval} onChange={e => changeInterval(Number(e.target.value))} aria-label="popup interval in minutes" />
          <div className="settings-row settings-row--hint"><span>20 min</span><span>24 hrs</span></div>
          <label className="settings-row">
            <span>or type minutes:</span>
            <input className="settings-control settings-control--narrow" inputMode="numeric" value={minutesText}
              onChange={e => setMinutesText(e.target.value.replace(/\D/g, ''))}
              onBlur={() => changeInterval(Number(minutesText) || interval)}
              onKeyDown={e => e.key === 'Enter' && e.currentTarget.blur()} />
          </label>
          <p className="settings-help">prompts only appear while ground is open in a browser tab.</p>
        </div>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">notifications</h2>
        <div className="settings-card settings-row">
          <span className="settings-stack">
            <span>check-in reminders</span>
            <span className={`settings-status settings-status--${notif}`}>{notifLabel}</span>
          </span>
          {notif === 'default' && <button className="btn-small" onClick={enableNotifications}>enable</button>}
          {notif === 'granted' && <span className="settings-check" aria-hidden="true">✓</span>}
        </div>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">friends</h2>
        <button className="settings-card settings-row settings-link" onClick={() => setShowFriends(true)}>
          <span className="settings-stack">
            <span>{profile?.username ? `@${profile.username}` : 'set up your handle'}</span>
            <span className="settings-help">{profile?.username ? 'tap to manage friends' : 'so friends can find you on Ground'}</span>
          </span>
          <span className="top-chevron">›</span>
        </button>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">account</h2>
        <div className="settings-card">
          <span className="settings-help">signed in as</span>
          <div>{session.user.email}</div>
        </div>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">change password</h2>
        <div className="settings-card settings-card--form">
          <input type="password" className="settings-control" placeholder="new password" value={newPassword}
            onChange={e => setNewPassword(e.target.value)} autoComplete="new-password" />
          <input type="password" className="settings-control" placeholder="confirm new password" value={confirmPassword}
            onChange={e => setConfirmPassword(e.target.value)} autoComplete="new-password"
            onKeyDown={e => e.key === 'Enter' && changePassword()} />
          {pwStatus && <p className={`picker-hint${pwStatus.warn ? ' picker-hint--warn' : ' picker-hint--ok'}`}>{pwStatus.text}</p>}
          <button className="btn-save" onClick={changePassword} disabled={!newPassword || savingPw}>
            {savingPw ? 'saving…' : 'update password'}
          </button>
        </div>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">legal</h2>
        <a className="settings-card settings-row settings-link" href={PRIVACY_URL} target="_blank" rel="noreferrer">
          <span>privacy policy</span><span aria-hidden="true">↗</span>
        </a>
        <a className="settings-card settings-row settings-link" href={TERMS_URL} target="_blank" rel="noreferrer">
          <span>terms of service</span><span aria-hidden="true">↗</span>
        </a>
      </section>

      <section className="settings-group">
        <h2 className="settings-label">session</h2>
        <button className="btn-outline" onClick={() => api.signOut().catch(e => setError(e.message))}>sign out</button>
        {confirmDelete ? (
          <div className="danger-card">
            <strong>delete account?</strong>
            <p>this permanently deletes your journal entries, memories, and account. this cannot be undone.</p>
            <div className="danger-actions">
              <button className="btn-small btn-small--ghost" onClick={() => setConfirmDelete(false)} disabled={deleting}>cancel</button>
              <button className="btn-danger" onClick={deleteAccount} disabled={deleting}>{deleting ? 'deleting…' : 'delete everything'}</button>
            </div>
          </div>
        ) : (
          <button className="btn-outline btn-outline--danger" onClick={() => setConfirmDelete(true)}>delete account</button>
        )}
      </section>
    </div>
  )
}
