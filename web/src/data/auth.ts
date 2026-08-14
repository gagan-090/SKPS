import { supabase } from '../lib/supabase';
import { AppError } from '../lib/errors';

/** The only place Supabase Auth is touched. Ports `auth_repository.dart`. */
export const authRepo = {
  async signIn(email: string, password: string): Promise<void> {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    if (error) throw AppError.from(error);
  },

  async signOut(): Promise<void> {
    const { error } = await supabase.auth.signOut();
    if (error) throw AppError.from(error);
  },

  /**
   * Sends the reset link. `redirectTo` must be listed under
   * Authentication → URL Configuration → Redirect URLs in Supabase, otherwise
   * the link bounces to the Site URL instead.
   */
  async resetPassword(email: string): Promise<void> {
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    if (error) throw AppError.from(error);
  },

  /** Used on the reset-password screen, once Supabase has set the recovery session. */
  async updatePassword(password: string): Promise<void> {
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw AppError.from(error);
  },

  async currentUserId(): Promise<string> {
    const { data } = await supabase.auth.getSession();
    const id = data.session?.user.id;
    if (!id) throw new AppError('Your session has expired. Please log in again.');
    return id;
  },
};
