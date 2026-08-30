import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/day_summary.dart';
import '../../data/models/employee.dart';
import '../attendance/attendance_controller.dart';
import '../employees/employees_controller.dart';

typedef ReportQuery = ({int year, int month, String? employeeId});

/// One row of the report matrix.
class ReportRow {
  const ReportRow({
    required this.employee,
    required this.byDay,
    required this.totals,
  });

  final Employee employee;

  /// Day-of-month (1..N) to record. Missing keys are unmarked days.
  final Map<int, AttendanceRecord> byDay;
  final EmployeeMonthTotals totals;

  /// Days before the employee joined print as "—", not as an absence.
  bool isBeforeJoining(int year, int month, int day) =>
      !employee.wasEmployedOn(DateTime(year, month, day));

  /// Total pay earned this month: each day's manual override, or the amount
  /// derived from the employee's daily rate and that day's status.
  double get monthSalary {
    var sum = 0.0;
    for (final AttendanceRecord record in byDay.values) {
      sum += record.amount ?? employee.defaultAmountFor(record.status);
    }
    return sum;
  }

  /// Whether this row has any pay information worth printing.
  bool get hasSalary =>
      employee.hasSalary ||
      byDay.values.any((AttendanceRecord r) => r.amount != null);
}

class ReportData {
  const ReportData({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.rows,
  });

  final int year;
  final int month;
  final int daysInMonth;
  final List<ReportRow> rows;

  String get monthLabel => AppDate.monthYear(year, month);

  bool get isEmpty =>
      rows.isEmpty ||
      rows.every((ReportRow row) => row.totals.totalMarked == 0);

  /// Distinct days with at least one record.
  int get daysMarked {
    final days = <int>{};
    for (final ReportRow row in rows) {
      days.addAll(row.byDay.keys);
    }
    return days.length;
  }

  /// Grand total pay across every included employee.
  double get totalSalary =>
      rows.fold(0, (double sum, ReportRow row) => sum + row.monthSalary);

  /// True when any included employee has pay information to show.
  bool get hasSalary => rows.any((ReportRow row) => row.hasSalary);

  /// A copy limited to the given employee ids, used to export a chosen subset.
  ReportData withEmployees(Set<String> employeeIds) {
    return ReportData(
      year: year,
      month: month,
      daysInMonth: daysInMonth,
      rows: rows
          .where((ReportRow row) => employeeIds.contains(row.employee.id))
          .toList(),
    );
  }
}

/// Builds the month matrix.
///
/// Included employees: everyone currently active who had joined by the end of
/// the month, plus anyone (including deactivated staff) who has a record in
/// that month — history must not disappear from past reports.
final reportProvider = FutureProvider.family<ReportData, ReportQuery>((
  Ref ref,
  ReportQuery query,
) async {
  final employees = await ref.watch(employeeListProvider.future);
  final records = await ref.watch(
    monthAttendanceProvider((
      year: query.year,
      month: query.month,
      employeeId: query.employeeId,
    )).future,
  );

  final range = AppDate.monthRange(query.year, query.month);
  final daysInMonth = AppDate.daysInMonth(query.year, query.month);

  final recordsByEmployee = <String, Map<int, AttendanceRecord>>{};
  for (final AttendanceRecord record in records) {
    recordsByEmployee.putIfAbsent(
      record.employeeId,
      () => <int, AttendanceRecord>{},
    )[record.day.day] = record;
  }

  final included = employees.where((Employee employee) {
    if (query.employeeId != null) return employee.id == query.employeeId;
    if (recordsByEmployee.containsKey(employee.id)) return true;
    return employee.isActive &&
        !AppDate.dateOnly(employee.joinedOn).isAfter(range.last);
  }).toList();

  final rows = included.map((Employee employee) {
    final byDay =
        recordsByEmployee[employee.id] ?? const <int, AttendanceRecord>{};
    return ReportRow(
      employee: employee,
      byDay: byDay,
      totals: EmployeeMonthTotals.fromRecords(employee.id, byDay.values),
    );
  }).toList();

  return ReportData(
    year: query.year,
    month: query.month,
    daysInMonth: daysInMonth,
    rows: rows,
  );
});
