import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Mirrors the `attendance_status` Postgres enum.
enum AttendanceStatus {
  present('present', 'Present', 'P', AppColors.present),
  absent('absent', 'Absent', 'A', AppColors.absent),
  halfDay('half_day', 'Half Day', 'H', AppColors.halfDay),
  leave('leave', 'Leave', 'L', AppColors.leave);

  const AttendanceStatus(this.dbValue, this.label, this.shortCode, this.color);

  /// The exact enum literal stored in Postgres.
  final String dbValue;

  final String label;

  /// One-letter code used in the segmented selector, calendar and reports.
  final String shortCode;

  final Color color;

  /// How much of a working day this status counts for, used for payroll-ish
  /// totals in the reports.
  double get dayValue => switch (this) {
    AttendanceStatus.present => 1,
    AttendanceStatus.halfDay => 0.5,
    AttendanceStatus.absent => 0,
    AttendanceStatus.leave => 0,
  };

  static AttendanceStatus fromDb(String value) {
    for (final status in AttendanceStatus.values) {
      if (status.dbValue == value) return status;
    }
    // Unknown value from a newer schema: treat as absent rather than crashing.
    return AttendanceStatus.absent;
  }

  static AttendanceStatus? tryFromDb(String? value) =>
      value == null ? null : fromDb(value);
}
