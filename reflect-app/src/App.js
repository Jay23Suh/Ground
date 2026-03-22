import { useState, useEffect } from 'react'
import { supabase } from './supabase'
import Auth from './Auth'
import Home from './Home'
import ResetPassword from './ResetPassword'
import './App.css'

export default function App() {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)
  const [isRecovery, setIsRecovery] = useState(false)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY') {
        setIsRecovery(true)
        setSession(session)
      } else {
        setIsRecovery(false)
        setSession(session)
      }
    })
    return () => subscription.unsubscribe()
  }, [])

  if (loading) return (
    <div className="loading-screen">
      <div className="loading-dot" />
    </div>
  )

  if (isRecovery) return <ResetPassword onDone={() => setIsRecovery(false)} />
  return session ? <Home session={session} /> : <Auth />
}
