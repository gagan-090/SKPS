/// Static app metadata.
///
/// Kept as constants rather than pulling in `package_info_plus` — this must
/// stay in step with the `version:` line in pubspec.yaml.
class AppInfo {
  const AppInfo._();

  static const String name = 'SKPS Attendance';
  static const String shortName = 'SKPS';
  static const String version = '1.0.0';
  static const String buildNumber = '1';

  static const String versionLabel = '$version ($buildNumber)';

  static const String tagline = 'Daily staff attendance, kept simple.';

  /// The SKPS mark, as shown on screen.
  static const String logoAsset = 'assets/brand/skps_logo.png';

  /// A smaller copy of the mark for the report header and watermark — the PDF
  /// package embeds bitmaps uncompressed, so full resolution is wasted there.
  static const String logoPrintAsset = 'assets/brand/skps_logo_print.png';
}
