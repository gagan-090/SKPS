/// Form validators shared across the app.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _indianMobile = RegExp(r'^[6-9][0-9]{9}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? employeeName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Name must be at least 2 characters';
    if (v.length > 80) return 'Name is too long';
    return null;
  }

  /// Mobile is optional, but when present it must be a valid Indian number.
  /// Mirrors the `mobile ~ '^[6-9][0-9]{9}$'` check in the database.
  static String? mobileOptional(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.length != 10) return 'Enter exactly 10 digits';
    if (!_indianMobile.hasMatch(v)) return 'Must start with 6, 7, 8 or 9';
    return null;
  }

  static bool isValidMobile(String? value) =>
      value != null && _indianMobile.hasMatch(value.trim());
}
