import { createClient } from '@supabase/supabase-js';

import { Env } from './env';

/**
 * The single Supabase client for the web app.
 *
 * It points at the *same* project as the Flutter app and relies on the same
 * Row Level Security policies in `supabase/schema.sql` — the owner only ever
 * sees rows where `owner_id = auth.uid()`.
 */
export const supabase = createClient(
  Env.supabaseUrl || 'https://placeholder.supabase.co',
  Env.supabaseAnonKey || 'placeholder',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // Needed so the password-reset link (`#access_token=...`) is picked up
      // when Supabase redirects the browser back to the app.
      detectSessionInUrl: true,
    },
  },
);
