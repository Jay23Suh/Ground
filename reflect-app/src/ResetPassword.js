import { useState } from 'react'
import { supabase } from './supabase'

export default function ResetPassword({ onDone }) {
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  const handleReset = async () => {
    if (password !== confirm) {
      setMessage('passwords do not match')
      return
    }
    setLoading(true)
    const { error } = await supabase.auth.updateUser({ password })
    if (error) {
      setMessage(error.message)
    } else {
      setMessage('password updated! signing you in...')
      setTimeout(onDone, 1500)
    }
    setLoading(false)
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-header">
          <span className="auth-star">✦</span>
          <h1>reset password</h1>
          <p>choose a new password</p>
        </div>
        <div className="auth-form">
          <input
            className="auth-input"
            type="password"
            placeholder="new password"
            value={password}
            onChange={e => setPassword(e.target.value)}
          />
          <input
            className="auth-input"
            type="password"
            placeholder="confirm password"
            value={confirm}
            onChange={e => setConfirm(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleReset()}
          />
          {message && <p className="auth-message">{message}</p>}
          <button className="auth-btn" onClick={handleReset} disabled={loading}>
            {loading ? '...' : 'update password'}
          </button>
        </div>
      </div>
    </div>
  )
}
