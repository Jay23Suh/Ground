import { useState, useEffect } from 'react'
import { supabase, isPasswordRecovery } from './supabase'
import Auth from './Auth'
import Home from './Home'
import ResetPassword from './ResetPassword'
import './App.css'

export default function App() {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)
  // Seed from URL hash — captured before Supabase clears it
  const [isRecovery, setIsRecovery] = useState(isPasswordRecovery)

  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY') {
        setIsRecovery(true)
        setSession(session)
        setLoading(false)
      } else if (event === 'SIGNED_OUT') {
        setIsRecovery(false)
        setSession(null)
        setLoading(false)
      } else {
        // INITIAL_SESSION or SIGNED_IN — only update session, don't clear recovery
        setSession(session)
        setLoading(false)
      }
    })

    const timeout = setTimeout(() => setLoading(false), 1000)

    return () => {
      subscription.unsubscribe()
      clearTimeout(timeout)
    }
  }, [])

  if (loading) return (
    <div className="loading-screen">
      <div className="loading-dot" />
    </div>
  )

  if (isRecovery) return <ResetPassword onDone={() => setIsRecovery(false)} />
  return session ? <Home session={session} /> : <Auth />
}
