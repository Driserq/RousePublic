// Supabase client for optional web tooling/tests. Not used by the iOS app runtime.
// Requires environment variables:
// - NEXT_PUBLIC_SUPABASE_URL
// - NEXT_PUBLIC_SUPABASE_ANON_KEY

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
	throw new Error('Missing SUPABASE env vars: NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY')
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
	auth: { persistSession: false }
})

// Optional connection test. Call from a Node script or dev console.
export async function testConnection() {
	try {
		// This query assumes a table named "Users" exists and is accessible via anon key.
		const { error } = await supabase
			.from('Users')
			.select('*', { count: 'exact', head: true })
			.limit(1)
		if (error) {
			console.error('Supabase testConnection error:', error)
			return false
		}
		console.log('Supabase connection OK')
		return true
	} catch (err) {
		console.error('Supabase testConnection exception:', err)
		return false
	}
}


