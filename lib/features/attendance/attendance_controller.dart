import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/offline_store.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/employee.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../employees/employees_controller.dart';
import 'sync_controller.dart';

/// The day currently open on the Mark Attendance screen.
class SelectedDayController extends Notifier<DateTime> {
  @override
  DateTime build() => AppDate.today();

  /// Future days are never markable.
  void select(DateTime day) {
    final target = AppDate.dateOnly(day);
    if (AppDate.isFuture(target)) return;
    if (AppDate.isSameDay(target, state)) return;
    state = target;
  }

  void previousDay() => select(state.subtract(const Duration(days: 1)));

  void nextDay() => select(state.add(const Duration(days: 1)));

  bool get canGoForward => !AppDate.isToday(state);
}

final NotifierProvider<SelectedDayController, DateTime> selectedDayProvider =
    NotifierProvider<SelectedDayController, DateTime>(
      SelectedDayController.new,
    );

/// Records for a single day, keyed by `YYYY-MM-DD`.
///
/// Offline-aware: successful fetches are cached, a network failure falls back
/// to that cache, and anything still sitting in the outbox is layered on top so
/// the owner sees what they marked even before it reaches the server.
final dayAttendanceProvider =
    FutureProvider.family<List<AttendanceRecord>, String>((
      Ref ref,
      String dayKey,
    ) async {
      final store = ref.watch(offlineStoreProvider);
      List<AttendanceRecord> records;

      try {
        records = await ref
            .watch(attendanceRepositoryProvider)
            .fetchForDay(AppDate.parseYmd(dayKey));
        await store.cacheDay(dayKey, records);
      } on AppException catch (error) {
        final cached = error.isNetwork ? store.cachedDay(dayKey) : null;
        if (cached == null) rethrow;
        records = cached;
      }

      final pending = store.pendingForDay(dayKey);
      if (pending.isEmpty) return records;

      final merged = <String, AttendanceRecord>{
        for (final AttendanceRecord record in records)
          record.employeeId: record,
        for (final AttendanceRecord record in pending)
          record.employeeId: record,
      };
      return merged.values.toList();
    });

/// Records for a whole month, optionally for one employee.
typedef MonthQuery = ({int year, int month, String? employeeId});

final monthAttendanceProvider =
    FutureProvider.family<List<AttendanceRecord>, MonthQuery>((
      Ref ref,
      MonthQuery query,
    ) {
      return ref
          .watch(attendanceRepositoryProvider)
          .fetchForMonth(
            year: query.year,
            month: query.month,
            employeeId: query.employeeId,
          );
    });

/// What happened when the owner pressed Save.
class SaveOutcome {
  const SaveOutcome.saved() : queuedOffline = false, errorMessage = null;

  const SaveOutcome.queued() : queuedOffline = true, errorMessage = null;

  const SaveOutcome.failed(String message)
    : queuedOffline = false,
      errorMessage = message;

  /// True when the rows went to the local outbox instead of the server.
  final bool queuedOffline;

  final String? errorMessage;

  bool get isFailure => errorMessage != null;
}

/// One editable row on the Mark Attendance screen.
class MarkEntry {
  const MarkEntry({
    this.status,
    this.note,
    this.amount,
    this.amountManual = false,
    this.noteVisible = false,
  });

  /// Null means "not marked".
  final AttendanceStatus? status;
  final String? note;

  /// The pay for the day. Auto-filled from the employee's daily rate when a
  /// status is picked; null means "no pay recorded".
  final double? amount;

  /// True once the owner has typed the amount by hand, so it is no longer
  /// re-derived when the status changes.
  final bool amountManual;

  /// Whether the note field is expanded for this row.
  final bool noteVisible;

  MarkEntry copyWith({
    AttendanceStatus? status,
    String? note,
    bool clearNote = false,
    double? amount,
    bool clearAmount = false,
    bool? amountManual,
    bool? noteVisible,
  }) {
    return MarkEntry(
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      amount: clearAmount ? null : (amount ?? this.amount),
      amountManual: amountManual ?? this.amountManual,
      noteVisible: noteVisible ?? this.noteVisible,
    );
  }
}

class MarkAttendanceState {
  const MarkAttendanceState({
    required this.day,
    required this.roster,
    required this.entries,
    this.saving = false,
  });

  final DateTime day;

  /// Active employees who had already joined on [day].
  final List<Employee> roster;
  final Map<String, MarkEntry> entries;
  final bool saving;

  int get markedCount =>
      entries.values.where((MarkEntry e) => e.status != null).length;

  int get total => roster.length;

  bool get allMarked => total > 0 && markedCount == total;

  List<Employee> get unmarked =>
      roster.where((Employee e) => entries[e.id]?.status == null).toList();

  int countOf(AttendanceStatus status) =>
      entries.values.where((MarkEntry e) => e.status == status).length;

  /// "10 Present · 2 Absent · 1 Half Day"
  String get breakdown {
    final parts = <String>[
      for (final AttendanceStatus status in AttendanceStatus.values)
        if (countOf(status) > 0) '${countOf(status)} ${status.label}',
    ];
    return parts.isEmpty ? 'Nothing marked yet' : parts.join(' · ');
  }

  MarkAttendanceState copyWith({
    List<Employee>? roster,
    Map<String, MarkEntry>? entries,
    bool? saving,
  }) {
    return MarkAttendanceState(
      day: day,
      roster: roster ?? this.roster,
      entries: entries ?? this.entries,
      saving: saving ?? this.saving,
    );
  }
}

class MarkAttendanceController extends AsyncNotifier<MarkAttendanceState> {
  @override
  Future<MarkAttendanceState> build() async {
    final day = ref.watch(selectedDayProvider);
    final employees = await ref.watch(employeeListProvider.future);
    final roster = EmployeeRepository.rosterFor(employees, day);

    // Existing records pre-select the selector, so this screen doubles as edit.
    final existing = await ref.watch(
      dayAttendanceProvider(AppDate.ymd(day)).future,
    );

    final rosterById = <String, Employee>{
      for (final Employee employee in roster) employee.id: employee,
    };
    final entries = <String, MarkEntry>{
      for (final Employee employee in roster) employee.id: const MarkEntry(),
    };
    for (final AttendanceRecord record in existing) {
      if (!entries.containsKey(record.employeeId)) continue;
      final employee = rosterById[record.employeeId]!;
      // A saved amount is treated as hand-set; otherwise pre-fill the rate.
      final manual = record.amount != null;
      entries[record.employeeId] = MarkEntry(
        status: record.status,
        note: record.note,
        amount: record.amount ?? defaultPay(employee, record.status),
        amountManual: manual,
        noteVisible: record.hasNote,
      );
    }

    return MarkAttendanceState(day: day, roster: roster, entries: entries);
  }

  /// The pay to pre-fill for [status] at [employee]'s daily rate, or null when
  /// there is nothing to earn that day (absent/leave) or no salary on file.
  static double? defaultPay(Employee employee, AttendanceStatus status) {
    if (!employee.hasSalary) return null;
    final amount = employee.defaultAmountFor(status);
    return amount > 0 ? amount : null;
  }

  Employee? _employeeFor(MarkAttendanceState state, String id) {
    for (final Employee employee in state.roster) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  /// Applies [status] to [entry], re-filling the auto pay unless it was set by
  /// hand.
  MarkEntry _withStatus(
    MarkEntry entry,
    AttendanceStatus status,
    Employee? employee,
  ) {
    final next = entry.copyWith(status: status);
    if (entry.amountManual) return next;
    final auto = employee == null ? null : defaultPay(employee, status);
    return auto == null
        ? next.copyWith(clearAmount: true)
        : next.copyWith(amount: auto);
  }

  MarkAttendanceState? get _current => state.value;

  void setStatus(String employeeId, AttendanceStatus status) {
    final current = _current;
    if (current == null || current.saving) return;
    final entry = current.entries[employeeId] ?? const MarkEntry();
    // Tapping the selected option again clears it back to "not marked".
    final next = entry.status == status
        ? MarkEntry(
            note: entry.note,
            amount: entry.amount,
            amountManual: entry.amountManual,
            noteVisible: entry.noteVisible,
          )
        : _withStatus(entry, status, _employeeFor(current, employeeId));
    _write(current, employeeId, next);
  }

  /// Records a hand-typed pay amount; from now on it is not re-derived.
  void setAmount(String employeeId, double? amount) {
    final current = _current;
    if (current == null || current.saving) return;
    final entry = current.entries[employeeId] ?? const MarkEntry();
    _write(
      current,
      employeeId,
      amount == null
          ? entry.copyWith(clearAmount: true, amountManual: true)
          : entry.copyWith(amount: amount, amountManual: true),
    );
  }

  void toggleNote(String employeeId) {
    final current = _current;
    if (current == null || current.saving) return;
    final entry = current.entries[employeeId] ?? const MarkEntry();
    _write(
      current,
      employeeId,
      entry.copyWith(noteVisible: !entry.noteVisible),
    );
  }

  void setNote(String employeeId, String note) {
    final current = _current;
    if (current == null || current.saving) return;
    final entry = current.entries[employeeId] ?? const MarkEntry();
    _write(
      current,
      employeeId,
      note.trim().isEmpty
          ? entry.copyWith(clearNote: true)
          : entry.copyWith(note: note),
    );
  }

  void markAllPresent() {
    final current = _current;
    if (current == null || current.saving) return;
    final rosterById = <String, Employee>{
      for (final Employee employee in current.roster) employee.id: employee,
    };
    state = AsyncValue<MarkAttendanceState>.data(
      current.copyWith(
        entries: <String, MarkEntry>{
          for (final MapEntry<String, MarkEntry> e in current.entries.entries)
            e.key: _withStatus(
              e.value,
              AttendanceStatus.present,
              rosterById[e.key],
            ),
        },
      ),
    );
  }

  /// Used by the "some are unmarked" dialog.
  void markRemainingAbsent() {
    final current = _current;
    if (current == null || current.saving) return;
    final rosterById = <String, Employee>{
      for (final Employee employee in current.roster) employee.id: employee,
    };
    state = AsyncValue<MarkAttendanceState>.data(
      current.copyWith(
        entries: <String, MarkEntry>{
          for (final MapEntry<String, MarkEntry> e in current.entries.entries)
            e.key: e.value.status == null
                ? _withStatus(
                    e.value,
                    AttendanceStatus.absent,
                    rosterById[e.key],
                  )
                : e.value,
        },
      ),
    );
  }

  void clearAll() {
    final current = _current;
    if (current == null || current.saving) return;
    state = AsyncValue<MarkAttendanceState>.data(
      current.copyWith(
        entries: <String, MarkEntry>{
          for (final String id in current.entries.keys) id: const MarkEntry(),
        },
      ),
    );
  }

  /// Saves every marked row in a single batched upsert.
  ///
  /// If the phone is offline the rows go into the local outbox instead and are
  /// flushed on the next successful connection — the owner's morning is not
  /// blocked by a weak signal.
  Future<SaveOutcome> save() async {
    final current = _current;
    if (current == null) {
      return const SaveOutcome.failed('Nothing to save yet.');
    }
    if (current.saving) return const SaveOutcome.saved();

    final records = <AttendanceRecord>[
      for (final Employee employee in current.roster)
        if (current.entries[employee.id]?.status != null)
          AttendanceRecord(
            employeeId: employee.id,
            day: current.day,
            status: current.entries[employee.id]!.status!,
            note: current.entries[employee.id]!.note,
            amount: current.entries[employee.id]!.amount,
          ),
    ];

    if (records.isEmpty) {
      return const SaveOutcome.failed(
        'Mark at least one employee before saving.',
      );
    }

    state = AsyncValue<MarkAttendanceState>.data(
      current.copyWith(saving: true),
    );

    try {
      await ref.read(attendanceRepositoryProvider).upsertMany(records);
      // Everything that reads attendance should pick this up.
      ref.invalidate(dayAttendanceProvider);
      ref.invalidate(monthAttendanceProvider);
      // A working connection is a good moment to drain anything still queued.
      unawaited(ref.read(syncProvider.notifier).flush());
      return const SaveOutcome.saved();
    } on AppException catch (error) {
      if (error.isNetwork) {
        await ref.read(syncProvider.notifier).enqueue(records);
        ref.invalidate(dayAttendanceProvider);
        return const SaveOutcome.queued();
      }
      final latest = _current;
      if (latest != null) {
        state = AsyncValue<MarkAttendanceState>.data(
          latest.copyWith(saving: false),
        );
      }
      return SaveOutcome.failed(error.message);
    }
  }

  void _write(MarkAttendanceState current, String employeeId, MarkEntry entry) {
    state = AsyncValue<MarkAttendanceState>.data(
      current.copyWith(
        entries: <String, MarkEntry>{...current.entries, employeeId: entry},
      ),
    );
  }
}

final AsyncNotifierProvider<MarkAttendanceController, MarkAttendanceState>
markAttendanceProvider =
    AsyncNotifierProvider<MarkAttendanceController, MarkAttendanceState>(
      MarkAttendanceController.new,
    );

/// Writes a single day for a single employee, used from the employee detail
/// calendar. Returns an error message, or null on success.
Future<String?> updateSingleDay(
  WidgetRef ref, {
  required String employeeId,
  required DateTime day,
  required AttendanceStatus? status,
  String? note,
  double? amount,
}) async {
  try {
    final repository = ref.read(attendanceRepositoryProvider);
    if (status == null) {
      await repository.deleteFor(employeeId: employeeId, day: day);
    } else {
      await repository.upsertOne(
        AttendanceRecord(
          employeeId: employeeId,
          day: day,
          status: status,
          note: note,
          amount: amount,
        ),
      );
    }
    ref.invalidate(dayAttendanceProvider);
    ref.invalidate(monthAttendanceProvider);
    return null;
  } on AppException catch (error) {
    return error.message;
  }
}
