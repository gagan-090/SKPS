import 'package:intl/intl.dart';

/// Rupee formatting shared across the app.
///
/// Two flavours: [format] for on-screen use (with the ₹ glyph, which the app
/// fonts render), and [plain] / [rupees] for PDF and CSV output, where the
/// built-in PDF fonts have no ₹ glyph so an "Rs" prefix is used instead.
class Money {
  const Money._();

  static final NumberFormat _grouped =
      NumberFormat.decimalPattern('en_IN');
  static final NumberFormat _grouped2 = NumberFormat('#,##,##0.00', 'en_IN');

  /// Whole rupees print without decimals; anything else keeps two places.
  static String plain(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? _grouped.format(rounded)
        : _grouped2.format(rounded);
  }

  /// `₹1,250` — for on-screen use.
  static String format(double value) => '₹${plain(value)}';

  /// `Rs 1,250` — for PDF where the ₹ glyph is unavailable.
  static String rupees(double value) => 'Rs ${plain(value)}';
}
