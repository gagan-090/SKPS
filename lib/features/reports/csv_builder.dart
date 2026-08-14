import 'package:csv/csv.dart';

import '../../core/utils/date_utils.dart';
import 'report_controller.dart';

/// Builds the monthly attendance CSV.
class CsvBuilder {
  const CsvBuilder._();

  /// `addBom: true` prefixes the UTF-8 byte order mark, which is the only way
  /// Excel on Windows reliably detects the encoding.
  static final Csv _codec = Csv(addBom: true, lineDelimiter: '\r\n');

  /// Header: `Employee, Mobile, 1, 2, ... N, Present, Absent, Half Day, Leave`.
  static String build(ReportData data) {
    final rows = <List<dynamic>>[];

    rows.add(<dynamic>[
      'Employee',
      'Mobile',
      for (int day = 1; day <= data.daysInMonth; day++) day,
      'Present',
      'Absent',
      'Half Day',
      'Leave',
      'Days Marked',
    ]);

    for (final ReportRow row in data.rows) {
      rows.add(<dynamic>[
        row.employee.name,
        row.employee.hasMobile ? row.employee.mobile! : '',
        for (int day = 1; day <= data.daysInMonth; day++) _cell(data, row, day),
        row.totals.present,
        row.totals.absent,
        row.totals.halfDay,
        row.totals.leave,
        row.totals.totalMarked,
      ]);
    }

    return _codec.encode(rows);
  }

  static String _cell(ReportData data, ReportRow row, int day) {
    final record = row.byDay[day];
    if (record != null) return record.status.shortCode;
    // Before joining is not an absence.
    return row.isBeforeJoining(data.year, data.month, day) ? '-' : '';
  }

  /// `Attendance_August_2026.csv`
  static String fileName(ReportData data, {String? employeeName}) {
    final month = AppDate.monthYear(data.year, data.month).replaceAll(' ', '_');
    final who = employeeName == null ? '' : '_${_slug(employeeName)}';
    return 'Attendance_$month$who.csv';
  }

  static String _slug(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
