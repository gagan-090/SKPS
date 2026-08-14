import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/date_utils.dart';
import '../../features/settings/settings_controller.dart';
import '../models/attendance_record.dart';
import '../models/attendance_status.dart';
import '../models/employee.dart';

/// Local cache and the outbox for attendance that could not be sent.
///
/// Everything lives in `shared_preferences` as JSON. This is small data — a
/// roster of a few dozen people and at most a handful of unsent days — so a
/// real local database would be overkill.
class OfflineStore {
  const OfflineStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _kRoster = 'cache_roster';
  static const String _kQueue = 'queue_attendance';
  static const String _kDayPrefix = 'cache_day_';

  /// How many recent days of attendance to keep on the device.
  static const int _dayCacheLimit = 10;

  // ---- roster -------------------------------------------------------------

  Future<void> cacheRoster(List<Employee> employees) async {
    final payload = employees
        .map(
          (Employee e) => <String, dynamic>{
            'id': e.id,
            'name': e.name,
            'mobile': e.mobile,
            'address': e.address,
            'is_active': e.isActive,
            'joined_on': AppDate.ymd(e.joinedOn),
          },
        )
        .toList();
    await _prefs.setString(_kRoster, jsonEncode(payload));
  }

  /// The last successfully fetched roster, or null if there has never been one.
  List<Employee>? cachedRoster() {
    final raw = _prefs.getString(_kRoster);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(Employee.fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ---- day cache ----------------------------------------------------------

  Future<void> cacheDay(String dayKey, List<AttendanceRecord> records) async {
    await _prefs.setString(
      '$_kDayPrefix$dayKey',
      jsonEncode(records.map(_encodeRecord).toList()),
    );
    await _trimDayCache();
  }

  List<AttendanceRecord>? cachedDay(String dayKey) {
    final raw = _prefs.getString('$_kDayPrefix$dayKey');
    if (raw == null) return null;
    return _decodeRecords(raw);
  }

  Future<void> _trimDayCache() async {
    final keys =
        _prefs
            .getKeys()
            .where((String key) => key.startsWith(_kDayPrefix))
            .toList()
          ..sort();
    if (keys.length <= _dayCacheLimit) return;
    for (final String key in keys.take(keys.length - _dayCacheLimit)) {
      await _prefs.remove(key);
    }
  }

  // ---- outbox -------------------------------------------------------------

  /// Adds records to the outbox, replacing any earlier entry for the same
  /// employee and day so the queue never grows with stale duplicates.
  Future<void> enqueue(List<AttendanceRecord> records) async {
    if (records.isEmpty) return;
    final merged = <String, AttendanceRecord>{
      for (final AttendanceRecord record in pending())
        '${record.employeeId}|${record.dayKey}': record,
      for (final AttendanceRecord record in records)
        '${record.employeeId}|${record.dayKey}': record,
    };
    await _prefs.setString(
      _kQueue,
      jsonEncode(merged.values.map(_encodeRecord).toList()),
    );
  }

  List<AttendanceRecord> pending() {
    final raw = _prefs.getString(_kQueue);
    if (raw == null) return const <AttendanceRecord>[];
    return _decodeRecords(raw) ?? const <AttendanceRecord>[];
  }

  /// Records still waiting to be sent for one specific day.
  List<AttendanceRecord> pendingForDay(String dayKey) => pending()
      .where((AttendanceRecord record) => record.dayKey == dayKey)
      .toList();

  int get pendingCount => pending().length;

  Future<void> clearPending() => _prefs.remove(_kQueue);

  // ---- json ---------------------------------------------------------------

  Map<String, dynamic> _encodeRecord(AttendanceRecord record) =>
      <String, dynamic>{
        'employee_id': record.employeeId,
        'day': record.dayKey,
        'status': record.status.dbValue,
        'note': record.note,
      };

  List<AttendanceRecord>? _decodeRecords(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> map) => AttendanceRecord(
              employeeId: map['employee_id'] as String,
              day: AppDate.parseYmd(map['day'] as String),
              status: AttendanceStatus.fromDb(map['status'] as String),
              note: map['note'] as String?,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }
}

final Provider<OfflineStore> offlineStoreProvider = Provider<OfflineStore>(
  (Ref ref) => OfflineStore(ref.watch(sharedPreferencesProvider)),
);
