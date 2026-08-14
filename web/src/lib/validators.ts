/** Form validators — a port of `lib/core/utils/validators.dart`. */

const EMAIL = /^[\w.+-]+@[\w-]+\.[\w.-]+$/;
const INDIAN_MOBILE = /^[6-9][0-9]{9}$/;

export const Validators = {
  email(value: string | null | undefined): string | null {
    const v = (value ?? '').trim();
    if (!v) return 'Email is required';
    if (!EMAIL.test(v)) return 'Enter a valid email address';
    return null;
  },

  password(value: string | null | undefined): string | null {
    const v = value ?? '';
    if (!v) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  },

  employeeName(value: string | null | undefined): string | null {
    const v = (value ?? '').trim();
    if (!v) return 'Name is required';
    if (v.length < 2) return 'Name must be at least 2 characters';
    if (v.length > 80) return 'Name is too long';
    return null;
  },

  /**
   * Mobile is optional, but when present it must be a valid Indian number.
   * Mirrors the `mobile ~ '^[6-9][0-9]{9}$'` check in the database.
   */
  mobileOptional(value: string | null | undefined): string | null {
    const v = (value ?? '').trim();
    if (!v) return null;
    if (v.length !== 10) return 'Enter exactly 10 digits';
    if (!INDIAN_MOBILE.test(v)) return 'Must start with 6, 7, 8 or 9';
    return null;
  },

  isValidMobile(value: string | null | undefined): boolean {
    return INDIAN_MOBILE.test((value ?? '').trim());
  },
};
