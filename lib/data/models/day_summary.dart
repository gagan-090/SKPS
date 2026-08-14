import 'attendance_record.dart';
import 'attendance_status.dart';

/// Aggregated counts for a single day, used by the dashboard tiles.
class DaySummary {
  const DaySummary({
    required this.totalActive,
    required this.present,
    required this.absent,
    required this.halfDay,
    required this.leave,
    this.lastMarkedAt,
  });

  final int totalActive;
  final int present;
  final int absent;
  final int halfDay;
  final int leave;

  /// When the most recent record for the day was written.
  final DateTime? lastMarkedAt;

  int get marked => present + absent + halfDay + leave;

  int get notMarked => (totalActive - marked).clamp(0, totalActive);

  bool get isMarked => marked > 0;

  bool get isComplete => totalActive > 0 && notMarked == 0;

  static const DaySummary empty = DaySummary(
    totalActive: 0,
    present: 0,
    absent: 0,
    halfDay: 0,
    leave: 0,
  );

  /// Counts [records], ignoring any that belong to employees not in
  /// [activeEmployeeIds] so deactivated staff never inflate today's numbers.
  factory DaySummary.fromRecords(
    Iterable<AttendanceRecord> records, {
    required Set<String> activeEmployeeIds,
  }) {
    var present = 0;
    var absent = 0;
    var halfDay = 0;
    var leave = 0;
    DateTime? lastMarkedAt;

    for (final record in records) {
      if (!activeEmployeeIds.contains(record.employeeId)) continue;
      switch (record.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.halfDay:
          halfDay++;
        case AttendanceStatus.leave:
          leave++;
      }
      final markedAt = record.markedAt;
      if (markedAt != null &&
          (lastMarkedAt == null || markedAt.isAfter(lastMarkedAt))) {
        lastMarkedAt = markedAt;
      }
    }

    return DaySummary(
      totalActive: activeEmployeeIds.length,
      present: present,
      absent: absent,
      halfDay: halfDay,
      leave: leave,
      lastMarkedAt: lastMarkedAt,
    );
  }

  /// One-line recap: "10 Present · 2 Absent · 1 Half Day".
  String get breakdown {
    final parts = <String>[
      if (present > 0) '$present Present',
      if (absent > 0) '$absent Absent',
      if (halfDay > 0) '$halfDay Half Day',
      if (leave > 0) '$leave Leave',
    ];
    return parts.isEmpty ? 'Nothing marked yet' : parts.join(' · ');
  }
}

/// Per-employee totals for a month.
class EmployeeMonthTotals {
  const EmployeeMonthTotals({
    required this.employeeId,
    required this.present,
    required this.absent,
    required this.halfDay,
    required this.leave,
  });

  final String employeeId;
  final int present;
  final int absent;
  final int halfDay;
  final int leave;

  int get totalMarked => present + absent + halfDay + leave;

  /// Present + half days counted as 0.5.
  double get payableDays => present + (halfDay * 0.5);

  static EmployeeMonthTotals fromRecords(
    String employeeId,
    Iterable<AttendanceRecord> records,
  ) {
    var present = 0;
    var absent = 0;
    var halfDay = 0;
    var leave = 0;
    for (final record in records) {
      switch (record.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.halfDay:
          halfDay++;
        case AttendanceStatus.leave:
          leave++;
      }
    }
    return EmployeeMonthTotals(
      employeeId: employeeId,
      present: present,
      absent: absent,
      halfDay: halfDay,
      leave: leave,
    );
  }
}
