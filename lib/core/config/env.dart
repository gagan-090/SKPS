/// Compile-time configuration supplied through `--dart-define`.
///
/// Values are never hardcoded here. Pass them at build/run time:
///
/// ```
/// flutter run --dart-define-from-file=.env
/// ```
///
/// or explicitly:
///
/// ```
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Names of the keys that were not supplied at build time.
  static List<String> get missingKeys => <String>[
    if (supabaseUrl.trim().isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
  ];

  static bool get isConfigured => missingKeys.isEmpty;

  /// Human readable explanation shown on screen when configuration is missing.
  static String get missingConfigMessage =>
      'Missing build configuration: ${missingKeys.join(', ')}.\n\n'
      'Run the app with:\n\n'
      'flutter run --dart-define-from-file=.env\n\n'
      'See .env.example and README.md for the expected values.';
}
