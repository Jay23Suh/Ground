import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.REACT_APP_SUPABASE_URL
const SUPABASE_ANON_KEY = process.env.REACT_APP_SUPABASE_ANON_KEY

// Must capture BEFORE createClient, which processes and clears the hash
export const isPasswordRecovery = window.location.hash.includes('type=recovery')

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
