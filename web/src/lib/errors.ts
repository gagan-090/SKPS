/**
 * The only error type that leaves a repository — a port of
 * `lib/core/errors/app_exception.dart`.
 *
 * Messages are written for the owner, never a raw PostgrestError.
 */
export class AppError extends Error {
  constructor(message: string, readonly cause?: unknown) {
    super(message);
    this.name = 'AppError';
  }

  static from(error: unknown): AppError {
    if (error instanceof AppError) return error;

    const raw = error as
      | { message?: string; code?: string; status?: number; name?: string }
      | null
      | undefined;

    const message = (raw?.message ?? '').toLowerCase();
    const code = raw?.code ?? '';

    // Offline / DNS / CORS all surface as a TypeError from fetch.
    if (
      raw?.name === 'TypeError' ||
      message.includes('failed to fetch') ||
      message.includes('networkerror') ||
      message.includes('load failed')
    ) {
      return new AppError(
        'No internet connection. Check your network and try again.',
        error,
      );
    }

    if (raw?.name === 'AbortError' || message.includes('timeout')) {
      return new AppError('The server took too long to respond. Try again.', error);
    }

    switch (code) {
      case '23505':
        return new AppError('That record already exists.', error);
      case '23514':
        return new AppError(
          'Some details are not valid. Check the mobile number and name.',
          error,
        );
      case '23503':
        return new AppError('That employee no longer exists.', error);
      case '42501':
      case 'PGRST301':
        return new AppError('Your session has expired. Please log in again.', error);
    }

    // Supabase Auth errors carry a readable message already.
    if (message.includes('invalid login credentials')) {
      return new AppError('Wrong email or password.', error);
    }
    if (message.includes('email not confirmed')) {
      return new AppError(
        'This account is not confirmed yet. Confirm it from the Supabase dashboard.',
        error,
      );
    }
    if (message.includes('rate limit') || raw?.status === 429) {
      return new AppError('Too many attempts. Wait a minute and try again.', error);
    }

    if (raw?.message) return new AppError(raw.message, error);
    return new AppError('Something went wrong. Please try again.', error);
  }
}

export const errorMessage = (error: unknown): string => AppError.from(error).message;
