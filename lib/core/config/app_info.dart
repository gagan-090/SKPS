/// Static app metadata.
///
/// Kept as constants rather than pulling in `package_info_plus` — this must
/// stay in step with the `version:` line in pubspec.yaml.
class AppInfo {
  const AppInfo._();

  static const String name = 'Attendance';
  static const String version = '1.0.0';
  static const String buildNumber = '1';

  static const String versionLabel = '$version ($buildNumber)';

  static const String tagline = 'Daily staff attendance, kept simple.';
}
