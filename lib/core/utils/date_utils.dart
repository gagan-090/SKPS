import 'package:intl/intl.dart';

/// Date helpers.
///
/// Every `day` value sent to Postgres is a naive `YYYY-MM-DD` string built from
/// the *local* device date. We never call `toIso8601String()` on a UTC
/// DateTime for a day column: India is UTC+05:30, so a UTC conversion before
/// 05:30 IST would silently shift the day backwards.
class AppDate {
  const AppDate._();

  static final DateFormat _display = DateFormat('dd MMM yyyy');
  static final DateFormat _displayLong = DateFormat('EEEE, dd MMM yyyy');
  static final DateFormat _displayShort = DateFormat('dd MMM');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _monthShort = DateFormat('MMM');
  static final DateFormat _time = DateFormat('h:mm a');

  /// `YYYY-MM-DD` from the local calendar date. The storage format.
  static String ymd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `YYYY-MM-DD` (also tolerates a full timestamp) into a local
  /// midnight DateTime.
  static DateTime parseYmd(String value) {
    final datePart = value.length >= 10 ? value.substring(0, 10) : value;
    final parts = datePart.split('-');
    if (parts.length != 3) return today();
    return DateTime(
      int.tryParse(parts[0]) ?? 1970,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  /// Strips any time component, keeping the local calendar date.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime today() => dateOnly(DateTime.now());

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isFuture(DateTime date) => dateOnly(date).isAfter(today());

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Inclusive first/last day of the given month.
  static ({DateTime first, DateTime last}) monthRange(int year, int month) => (
    first: DateTime(year, month, 1),
    last: DateTime(year, month, daysInMonth(year, month)),
  );

  // ---- display formatters -------------------------------------------------

  /// `05 Aug 2026`
  static String display(DateTime date) => _display.format(date);

  /// `Wednesday, 05 Aug 2026`
  static String displayLong(DateTime date) => _displayLong.format(date);

  /// `05 Aug`
  static String displayShort(DateTime date) => _displayShort.format(date);

  /// `August 2026`
  static String monthYear(int year, int month) =>
      _monthYear.format(DateTime(year, month));

  /// `Aug`
  static String monthAbbr(int month) =>
      _monthShort.format(DateTime(2000, month));

  /// `9:42 AM`
  static String time(DateTime dateTime) => _time.format(dateTime.toLocal());

  /// Single letter weekday header used by the calendar grid (`M`, `T`, ...).
  static String weekdayInitial(int weekday) {
    const initials = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return initials[(weekday - 1).clamp(0, 6)];
  }

  /// A friendly label for the attendance date selector.
  static String relativeLabel(DateTime date) {
    final t = today();
    final d = dateOnly(date);
    final diff = t.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return display(d);
  }
}
