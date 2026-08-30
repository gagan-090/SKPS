import '../../core/utils/date_utils.dart';
import 'attendance_status.dart';

/// One employee's status on one calendar day.
///
/// The database enforces `unique (employee_id, day)`, so a record is uniquely
/// addressed by that pair and every write is an upsert on it.
class AttendanceRecord {
  const AttendanceRecord({
    required this.employeeId,
    required this.day,
    required this.status,
    this.id,
    this.ownerId,
    this.note,
    this.amount,
    this.markedAt,
  });

  final String? id;
  final String? ownerId;
  final String employeeId;

  /// Local calendar date. Serialised as `YYYY-MM-DD`, never as a timestamp.
  final DateTime day;
  final AttendanceStatus status;
  final String? note;

  /// Manual pay override for this day, in rupees. Null means "derive it from
  /// the employee's daily rate and this day's status".
  final double? amount;
  final DateTime? markedAt;

  String get dayKey => AppDate.ymd(day);

  bool get hasNote => (note ?? '').trim().isNotEmpty;

  bool get hasAmount => amount != null;

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String?,
      ownerId: map['owner_id'] as String?,
      employeeId: map['employee_id'] as String,
      day: AppDate.parseYmd(map['day'] as String? ?? ''),
      status: AttendanceStatus.fromDb(map['status'] as String? ?? 'absent'),
      note: (map['note'] as String?)?.trim(),
      amount: _toDouble(map['amount']),
      markedAt: map['marked_at'] == null
          ? null
          : DateTime.tryParse(map['marked_at'] as String)?.toLocal(),
    );
  }

  /// Postgres `numeric` can arrive as a num or a string; be tolerant of both.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Upsert payload. `owner_id` is added by the repository from the session.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'employee_id': employeeId,
    'day': AppDate.ymd(day),
    'status': status.dbValue,
    'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    'amount': amount,
  };

  AttendanceRecord copyWith({
    String? id,
    String? ownerId,
    String? employeeId,
    DateTime? day,
    AttendanceStatus? status,
    String? note,
    bool clearNote = false,
    double? amount,
    bool clearAmount = false,
    DateTime? markedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      employeeId: employeeId ?? this.employeeId,
      day: day ?? this.day,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      amount: clearAmount ? null : (amount ?? this.amount),
      markedAt: markedAt ?? this.markedAt,
    );
  }
}
