import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../models/attendance_record.dart';

/// The only place `attendance` rows are read or written.
///
/// Every write is an upsert on the `(employee_id, day)` unique constraint, so
/// re-marking a day overwrites the previous value instead of duplicating it.
class AttendanceRepository {
  const AttendanceRepository();

  static const String _table = 'attendance';
  static const String _conflictTarget = 'employee_id,day';

  SupabaseClient get _client => Supabase.instance.client;

  String get _ownerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException(
        'Your session has expired. Please log in again.',
      );
    }
    return id;
  }

  Future<List<AttendanceRecord>> fetchForDay(DateTime day) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('day', AppDate.ymd(day));
      return rows
          .map((Map<String, dynamic> row) => AttendanceRecord.fromMap(row))
          .toList();
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  /// Inclusive range fetch, optionally narrowed to a single employee.
  Future<List<AttendanceRecord>> fetchForRange({
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) async {
    try {
      var filter = _client
          .from(_table)
          .select()
          .gte('day', AppDate.ymd(from))
          .lte('day', AppDate.ymd(to));
      if (employeeId != null) {
        filter = filter.eq('employee_id', employeeId);
      }
      final rows = await filter.order('day');
      return rows
          .map((Map<String, dynamic> row) => AttendanceRecord.fromMap(row))
          .toList();
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<List<AttendanceRecord>> fetchForMonth({
    required int year,
    required int month,
    String? employeeId,
  }) {
    final range = AppDate.monthRange(year, month);
    return fetchForRange(
      from: range.first,
      to: range.last,
      employeeId: employeeId,
    );
  }

  /// Saves the whole day in one request.
  ///
  /// A single batched upsert, never N calls: the Mark Attendance screen can
  /// have dozens of rows and each round trip on a weak connection hurts.
  Future<List<AttendanceRecord>> upsertMany(
    List<AttendanceRecord> records,
  ) async {
    if (records.isEmpty) return const <AttendanceRecord>[];
    try {
      final ownerId = _ownerId;
      final markedAt = DateTime.now().toUtc().toIso8601String();
      final payload = records
          .map(
            (AttendanceRecord record) => <String, dynamic>{
              ...record.toMap(),
              'owner_id': ownerId,
              'marked_at': markedAt,
            },
          )
          .toList();

      final rows = await _client
          .from(_table)
          .upsert(
            payload,
            onConflict: _conflictTarget,
            // Keep column defaults (id, created timestamps) for missing keys
            // instead of writing NULL over them.
            defaultToNull: false,
          )
          .select();

      return rows
          .map((Map<String, dynamic> row) => AttendanceRecord.fromMap(row))
          .toList();
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<AttendanceRecord> upsertOne(AttendanceRecord record) async {
    final saved = await upsertMany(<AttendanceRecord>[record]);
    return saved.isEmpty ? record : saved.first;
  }

  /// Clears a single day for one employee (back to "not marked").
  Future<void> deleteFor({
    required String employeeId,
    required DateTime day,
  }) async {
    try {
      await _client
          .from(_table)
          .delete()
          .eq('employee_id', employeeId)
          .eq('day', AppDate.ymd(day));
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }
}

final Provider<AttendanceRepository> attendanceRepositoryProvider =
    Provider<AttendanceRepository>((Ref ref) => const AttendanceRepository());
