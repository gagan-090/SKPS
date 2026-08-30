import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/employee_avatar.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/employee.dart';
import 'attendance_controller.dart';
import 'widgets/status_selector.dart';

/// The screen the owner uses every morning. Optimised for speed: one tap per
/// person, one "Mark All Present" shortcut, one batched save.
class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key, required this.initialDay});

  final DateTime initialDay;

  @override
  ConsumerState<MarkAttendanceScreen> createState() =>
      _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // The day lives in a provider so the controller can watch it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedDayProvider.notifier).select(widget.initialDay);
    });
  }

  Future<void> _pickDate(DateTime current) async {
    final today = AppDate.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(today.year - 3),
      // Attendance cannot be marked for a day that has not happened yet.
      lastDate: today,
      helpText: 'Attendance date',
    );
    if (picked == null || !mounted) return;
    ref.read(selectedDayProvider.notifier).select(picked);
  }

  Future<void> _save(MarkAttendanceState state) async {
    final controller = ref.read(markAttendanceProvider.notifier);

    if (!state.allMarked && state.unmarked.isNotEmpty) {
      final choice = await _askAboutUnmarked(state.unmarked.length);
      if (choice == null || !mounted) return;
      if (choice == _UnmarkedChoice.markRestAbsent) {
        controller.markRemainingAbsent();
      }
    }

    final outcome = await controller.save();
    if (!mounted) return;

    if (outcome.isFailure) {
      context.showFailure(outcome.errorMessage!);
      return;
    }

    context.showSuccess(
      outcome.queuedOffline
          ? 'Saved on this phone. It will sync when you are back online.'
          : 'Attendance saved',
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<_UnmarkedChoice?> _askAboutUnmarked(int count) {
    return showDialog<_UnmarkedChoice>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Some employees are unmarked'),
        content: Text(
          '$count ${count == 1 ? 'employee has' : 'employees have'} no status '
          'for this day. What would you like to do?',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_UnmarkedChoice.saveAnyway),
            child: const Text('Save anyway'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_UnmarkedChoice.markRestAbsent),
            child: const Text('Mark rest absent'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(selectedDayProvider);
    final async = ref.watch(markAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Mark Attendance'),
            Text(AppDate.displayLong(day), style: context.text.bodySmall),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Previous day',
            onPressed: () =>
                ref.read(selectedDayProvider.notifier).previousDay(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: AppDate.isToday(day)
                ? null
                : () => ref.read(selectedDayProvider.notifier).nextDay(),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: 'Pick a date',
            onPressed: () => _pickDate(day),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          AppSpacing.wGapXs,
        ],
      ),
      body: async.when(
        loading: () => const ListSkeleton(),
        error: (Object error, StackTrace stack) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(markAttendanceProvider),
        ),
        data: (MarkAttendanceState state) =>
            _MarkBody(state: state, onSave: () => _save(state)),
      ),
    );
  }
}

enum _UnmarkedChoice { markRestAbsent, saveAnyway }

class _MarkBody extends ConsumerWidget {
  const _MarkBody({required this.state, required this.onSave});

  final MarkAttendanceState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.roster.isEmpty) {
      return EmptyState(
        icon: Icons.group_add_outlined,
        title: 'No employees to mark',
        message:
            'Nobody on your roster was active on '
            '${AppDate.display(state.day)}. Add an employee to get started.',
        actionLabel: 'Add Employee',
        onAction: () => context.push(AppRoutes.employeeNew),
      );
    }

    final controller = ref.read(markAttendanceProvider.notifier);

    return Column(
      children: <Widget>[
        _StickyHeader(state: state),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemCount: state.roster.length,
            separatorBuilder: (_, _) => AppSpacing.gapCards,
            itemBuilder: (BuildContext context, int index) {
              final employee = state.roster[index];
              return _MarkRow(
                employee: employee,
                entry: state.entries[employee.id] ?? const MarkEntry(),
                enabled: !state.saving,
                onStatus: (AttendanceStatus status) =>
                    controller.setStatus(employee.id, status),
                onToggleNote: () => controller.toggleNote(employee.id),
                onNoteChanged: (String note) =>
                    controller.setNote(employee.id, note),
                onAmountChanged: (double? amount) =>
                    controller.setAmount(employee.id, amount),
              );
            },
          ),
        ),
        _SaveBar(state: state, onSave: onSave),
      ],
    );
  }
}

class _StickyHeader extends ConsumerWidget {
  const _StickyHeader({required this.state});

  final MarkAttendanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = state.total == 0 ? 0.0 : state.markedCount / state.total;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${state.markedCount} of ${state.total} marked',
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(state.breakdown, style: context.text.bodySmall),
                  ],
                ),
              ),
              AppSpacing.wGapSm,
              FilledButton.tonal(
                onPressed: state.saving
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(markAttendanceProvider.notifier)
                            .markAllPresent();
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  backgroundColor: context.colors.primaryContainer,
                  foregroundColor: context.colors.onPrimaryContainer,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,
                  ),
                ),
                child: const Text('Mark All Present'),
              ),
            ],
          ),
          AppSpacing.gapMd,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.colors.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkRow extends StatefulWidget {
  const _MarkRow({
    required this.employee,
    required this.entry,
    required this.enabled,
    required this.onStatus,
    required this.onToggleNote,
    required this.onNoteChanged,
    required this.onAmountChanged,
  });

  final Employee employee;
  final MarkEntry entry;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onStatus;
  final VoidCallback onToggleNote;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<double?> onAmountChanged;

  @override
  State<_MarkRow> createState() => _MarkRowState();
}

class _MarkRowState extends State<_MarkRow> {
  late final TextEditingController _noteController = TextEditingController(
    text: widget.entry.note ?? '',
  );
  late final TextEditingController _amountController = TextEditingController(
    text: widget.entry.amount == null
        ? ''
        : Money.plain(widget.entry.amount!).replaceAll(',', ''),
  );

  @override
  void didUpdateWidget(_MarkRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect an auto-filled amount (e.g. after picking a status) in the field,
    // but never overwrite an amount the owner is typing by hand.
    if (!widget.entry.amountManual) {
      final text = widget.entry.amount == null
          ? ''
          : Money.plain(widget.entry.amount!).replaceAll(',', '');
      if (text != _amountController.text) {
        _amountController.text = text;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Hint under the amount field explaining where the pre-filled value comes
  /// from, so the owner knows it is the profile rate they can override.
  String get _amountHint {
    final employee = widget.employee;
    if (!employee.hasSalary) return 'Optional — leave blank to skip';
    return 'From ${Money.format(employee.perDaySalary)}/day rate · edit to override';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      borderColor: entry.status?.color.withValues(alpha: 0.35),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              EmployeeAvatar(name: widget.employee.name, size: 40),
              AppSpacing.wGapMd,
              Expanded(
                child: Text(
                  widget.employee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
              ),
              IconButton(
                tooltip: entry.noteVisible ? 'Hide note' : 'Add note',
                onPressed: widget.enabled ? widget.onToggleNote : null,
                iconSize: 20,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                style: IconButton.styleFrom(
                  foregroundColor: entry.hasNoteText
                      ? context.colors.primary
                      : context.mutedColor,
                ),
                icon: Icon(
                  entry.hasNoteText
                      ? Icons.sticky_note_2_rounded
                      : Icons.sticky_note_2_outlined,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          StatusSelector(
            selected: entry.status,
            enabled: widget.enabled,
            onSelected: widget.onStatus,
          ),
          if (entry.status != null) ...<Widget>[
            AppSpacing.gapMd,
            TextField(
              controller: _amountController,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (String value) =>
                  widget.onAmountChanged(Validators.parseAmount(value)),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                helperText: _amountHint,
                isDense: true,
              ),
            ),
          ],
          if (entry.noteVisible) ...<Widget>[
            AppSpacing.gapMd,
            TextField(
              controller: _noteController,
              enabled: widget.enabled,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              onChanged: widget.onNoteChanged,
              decoration: const InputDecoration(
                hintText: 'Note (optional)',
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on MarkEntry {
  bool get hasNoteText => (note ?? '').trim().isNotEmpty;
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.state, required this.onSave});

  final MarkAttendanceState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Ready to save', style: context.text.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    state.breakdown,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            AppSpacing.wGapMd,
            PrimaryButton(
              label: 'Save',
              icon: Icons.check_rounded,
              expand: false,
              loading: state.saving,
              onPressed: state.markedCount == 0 ? null : onSave,
            ),
          ],
        ),
      ),
    );
  }
}
