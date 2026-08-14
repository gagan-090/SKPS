import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/day_summary.dart';
import '../../data/models/employee.dart';
import '../attendance/attendance_controller.dart';
import '../attendance/sync_controller.dart';
import '../employees/employees_controller.dart';

/// One employee's present-day tally for the current month.
class MonthTally {
  const MonthTally({
    required this.employee,
    required this.presentDays,
    required this.halfDays,
  });

  final Employee employee;
  final int presentDays;
  final int halfDays;

  /// Half days count as half a day.
  double get effectiveDays => presentDays + (halfDays * 0.5);
}

class DashboardData {
  const DashboardData({
    required this.day,
    required this.today,
    required this.activeCount,
    required this.daysMarkedThisMonth,
    required this.tallies,
  });

  final DateTime day;
  final DaySummary today;
  final int activeCount;

  /// Distinct days in the current month that have at least one record.
  final int daysMarkedThisMonth;

  /// Every active employee's month tally, best first.
  final List<MonthTally> tallies;

  bool get hasEmployees => activeCount > 0;
}

/// Composes the home screen from the roster, today's records and this month's
/// records. Each part is its own provider, so a save on any screen refreshes
/// the dashboard automatically.
final dashboardProvider = FutureProvider<DashboardData>((Ref ref) async {
  final employees = await ref.watch(employeeListProvider.future);
  final today = AppDate.today();

  final dayRecords = await ref.watch(
    dayAttendanceProvider(AppDate.ymd(today)).future,
  );
  final monthRecords = await ref.watch(
    monthAttendanceProvider((
      year: today.year,
      month: today.month,
      employeeId: null,
    )).future,
  );

  final active = employees.where((Employee e) => e.isActive).toList();
  final activeIds = active.map((Employee e) => e.id).toSet();

  final summary = DaySummary.fromRecords(
    dayRecords,
    activeEmployeeIds: activeIds,
  );

  final markedDays = <String>{
    for (final AttendanceRecord record in monthRecords) record.dayKey,
  };

  final presentByEmployee = <String, int>{};
  final halfByEmployee = <String, int>{};
  for (final AttendanceRecord record in monthRecords) {
    if (record.status == AttendanceStatus.present) {
      presentByEmployee.update(
        record.employeeId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    } else if (record.status == AttendanceStatus.halfDay) {
      halfByEmployee.update(
        record.employeeId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  final tallies =
      active
          .map(
            (Employee employee) => MonthTally(
              employee: employee,
              presentDays: presentByEmployee[employee.id] ?? 0,
              halfDays: halfByEmployee[employee.id] ?? 0,
            ),
          )
          .toList()
        ..sort((MonthTally a, MonthTally b) {
          final byDays = b.effectiveDays.compareTo(a.effectiveDays);
          if (byDays != 0) return byDays;
          return a.employee.name.toLowerCase().compareTo(
            b.employee.name.toLowerCase(),
          );
        });

  return DashboardData(
    day: today,
    today: summary,
    activeCount: active.length,
    daysMarkedThisMonth: markedDays.length,
    tallies: tallies,
  );
});

/// Pull-to-refresh: drain the offline outbox, then rebuild the roster and
/// every attendance query.
Future<void> refreshDashboard(WidgetRef ref) async {
  await ref.read(syncProvider.notifier).flush();
  ref.invalidate(dayAttendanceProvider);
  ref.invalidate(monthAttendanceProvider);
  await ref.read(employeeListProvider.notifier).refresh();
  await ref.read(dashboardProvider.future);
}
