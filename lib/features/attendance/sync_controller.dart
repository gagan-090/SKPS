import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/local/offline_store.dart';
import '../../data/models/attendance_record.dart';
import '../../data/repositories/attendance_repository.dart';
import 'attendance_controller.dart';

class SyncState {
  const SyncState({this.pending = 0, this.syncing = false, this.lastError});

  /// Number of attendance rows waiting to reach the server.
  final int pending;
  final bool syncing;
  final String? lastError;

  bool get hasPending => pending > 0;
}

/// Owns the offline outbox: how many rows are waiting, and flushing them.
class SyncController extends Notifier<SyncState> {
  OfflineStore get _store => ref.read(offlineStoreProvider);

  @override
  SyncState build() =>
      SyncState(pending: ref.watch(offlineStoreProvider).pendingCount);

  /// Called after a failed save so the work is not lost.
  Future<void> enqueue(List<AttendanceRecord> records) async {
    await _store.enqueue(records);
    state = SyncState(pending: _store.pendingCount);
  }

  void refreshCount() {
    final pending = _store.pendingCount;
    if (pending == state.pending) return;
    state = state.copyWith(pending: pending);
  }

  /// Tries to send everything in the outbox.
  ///
  /// Safe to call speculatively — it does nothing when the queue is empty or a
  /// flush is already running, and it leaves the queue untouched on failure.
  Future<bool> flush() async {
    if (state.syncing) return false;
    final queued = _store.pending();
    if (queued.isEmpty) {
      if (state.pending != 0) state = const SyncState();
      return true;
    }

    state = state.copyWith(syncing: true, clearError: true);
    try {
      await ref.read(attendanceRepositoryProvider).upsertMany(queued);
      await _store.clearPending();
      state = const SyncState();
      ref.invalidate(dayAttendanceProvider);
      ref.invalidate(monthAttendanceProvider);
      return true;
    } on AppException catch (error) {
      state = SyncState(pending: _store.pendingCount, lastError: error.message);
      return false;
    }
  }
}

extension on SyncState {
  SyncState copyWith({
    int? pending,
    bool? syncing,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncState(
      pending: pending ?? this.pending,
      syncing: syncing ?? this.syncing,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final NotifierProvider<SyncController, SyncState> syncProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
