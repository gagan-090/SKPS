import 'package:url_launcher/url_launcher.dart';

/// Tap-to-call and WhatsApp deep links for employee mobile numbers.
///
/// Numbers are stored as 10 digits; the +91 country code is added here.
class ContactLauncher {
  const ContactLauncher._();

  static const String _countryCode = '91';

  static Future<bool> call(String mobile) =>
      _open(Uri(scheme: 'tel', path: '+$_countryCode$mobile'));

  static Future<bool> whatsApp(String mobile, {String? message}) {
    final uri = Uri.parse(
      'https://wa.me/$_countryCode$mobile'
      '${message == null ? '' : '?text=${Uri.encodeComponent(message)}'}',
    );
    return _open(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> sms(String mobile) =>
      _open(Uri(scheme: 'sms', path: '+$_countryCode$mobile'));

  static Future<bool> _open(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      // No dialer / WhatsApp installed, or the platform refused the intent.
      return false;
    }
  }
}
