import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/employee_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/month_selector.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/day_summary.dart';
import '../../data/models/employee.dart';
import '../attendance/attendance_controller.dart';
import 'employees_controller.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  ConsumerState<EmployeeDetailScreen> createState() =>
      _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  Future<void> _contact(Future<bool> Function() action, String failure) async {
    final launched = await action();
    if (!mounted || launched) return;
    context.showFailure(failure);
  }

  Future<void> _editDay(
    Employee employee,
    DateTime day,
    AttendanceStatus? current,
    String? note,
  ) async {
    final result = await showModalBottomSheet<_DayEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _DayStatusSheet(
        employeeName: employee.name,
        day: day,
        status: current,
        note: note,
      ),
    );
    if (result == null || !mounted) return;

    final error = await updateSingleDay(
      ref,
      employeeId: employee.id,
      day: day,
      status: result.status,
      note: result.note,
    );
    if (!mounted) return;

    if (error != null) {
      context.showFailure(error);
    } else {
      context.showSuccess(
        result.status == null
            ? 'Cleared ${AppDate.display(day)}'
            : '${AppDate.display(day)} marked ${result.status!.label}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final employee = ref.watch(employeeByIdProvider(widget.employeeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee'),
        actions: <Widget>[
          if (employee != null)
            IconButton(
              tooltip: 'Edit',
              onPressed: () =>
                  context.push(AppRoutes.employeeEdit(employee.id)),
              icon: const Icon(Icons.edit_outlined),
            ),
          AppSpacing.wGapXs,
        ],
      ),
      body: employeesAsync.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorView(
          error: error,
          onRetry: () => ref.read(employeeListProvider.notifier).refresh(),
        ),
        data: (_) {
          if (employee == null) {
            return const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Employee not found',
              message: 'This employee may have been deleted.',
            );
          }
          return _DetailBody(
            employee: employee,
            year: _year,
            month: _month,
            onMonthChanged: (int year, int month) => setState(() {
              _year = year;
              _month = month;
            }),
            onCall: () => _contact(
              () => ContactLauncher.call(employee.mobile!),
              'Could not open the dialer.',
            ),
            onWhatsApp: () => _contact(
              () => ContactLauncher.whatsApp(employee.mobile!),
              'WhatsApp is not installed.',
            ),
            onEditDay: (DateTime day, AttendanceStatus? status, String? note) =>
                _editDay(employee, day, status, note),
          );
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.employee,
    required this.year,
    required this.month,
    required this.onMonthChanged,
    required this.onCall,
    required this.onWhatsApp,
    required this.onEditDay,
  });

  final Employee employee;
  final int year;
  final int month;
  final void Function(int year, int month) onMonthChanged;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final void Function(DateTime day, AttendanceStatus? status, String? note)
  onEditDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (year: year, month: month, employeeId: employee.id);
    final recordsAsync = ref.watch(monthAttendanceProvider(query));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _ProfileCard(
          employee: employee,
          onCall: onCall,
          onWhatsApp: onWhatsApp,
        ),
        AppSpacing.gapCards,
        MonthSelector(year: year, month: month, onChanged: onMonthChanged),
        AppSpacing.gapCards,
        recordsAsync.when(
          loading: () =>
              const AppCard(child: SizedBox(height: 240, child: LoadingView())),
          error: (Object error, StackTrace stack) => AppCard(
            child: SizedBox(
              height: 240,
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(monthAttendanceProvider(query)),
              ),
            ),
          ),
          data: (List<AttendanceRecord> records) => _MonthCalendarCard(
            employee: employee,
            year: year,
            month: month,
            records: records,
            onEditDay: onEditDay,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.employee,
    required this.onCall,
    required this.onWhatsApp,
  });

  final Employee employee;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmployeeAvatar(
                name: employee.name,
                size: 56,
                inactive: !employee.isActive,
              ),
              AppSpacing.wGapLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(employee.name, style: context.text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      employee.isActive ? 'Active' : 'Inactive',
                      style: context.text.bodySmall?.copyWith(
                        color: employee.isActive
                            ? context.colors.primary
                            : context.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          if (employee.hasMobile) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: onCall,
                    borderRadius: AppRadius.buttonRadius,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.call_outlined,
                            size: 20,
                            color: context.colors.primary,
                          ),
                          AppSpacing.wGapMd,
                          Expanded(
                            child: Text(
                              employee.displayMobile,
                              style: context.text.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                ),
              ],
            ),
            Divider(color: context.hairline),
          ],
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'Joined on',
            value: AppDate.display(employee.joinedOn),
          ),
          if ((employee.address ?? '').isNotEmpty) ...<Widget>[
            Divider(color: context.hairline),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: employee.address!,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: context.mutedColor),
          AppSpacing.wGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: context.text.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard({
    required this.employee,
    required this.year,
    required this.month,
    required this.records,
    required this.onEditDay,
  });

  final Employee employee;
  final int year;
  final int month;
  final List<AttendanceRecord> records;
  final void Function(DateTime day, AttendanceStatus? status, String? note)
  onEditDay;

  @override
  Widget build(BuildContext context) {
    final byDay = <int, AttendanceRecord>{
      for (final AttendanceRecord record in records) record.day.day: record,
    };
    final totals = EmployeeMonthTotals.fromRecords(employee.id, records);
    final daysInMonth = AppDate.daysInMonth(year, month);
    final firstWeekday = DateTime(year, month).weekday; // Monday = 1
    final today = AppDate.today();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: 'Attendance'),
          Row(
            children: <Widget>[
              for (int weekday = 1; weekday <= 7; weekday++)
                Expanded(
                  child: Center(
                    child: Text(
                      AppDate.weekdayInitial(weekday),
                      style: context.text.labelSmall?.copyWith(
                        color: context.mutedColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.gapSm,
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            children: <Widget>[
              for (int i = 1; i < firstWeekday; i++) const SizedBox.shrink(),
              for (int dayNumber = 1; dayNumber <= daysInMonth; dayNumber++)
                _CalendarCell(
                  day: DateTime(year, month, dayNumber),
                  record: byDay[dayNumber],
                  // Days before joining are not absences.
                  beforeJoining: !employee.wasEmployedOn(
                    DateTime(year, month, dayNumber),
                  ),
                  inFuture: DateTime(year, month, dayNumber).isAfter(today),
                  onTap: onEditDay,
                ),
            ],
          ),
          AppSpacing.gapLg,
          Divider(color: context.hairline),
          AppSpacing.gapMd,
          if (records.isEmpty)
            Text(
              'No attendance recorded in this month.',
              style: context.text.bodySmall,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _TotalPill(
                  status: AttendanceStatus.present,
                  count: totals.present,
                ),
                _TotalPill(
                  status: AttendanceStatus.absent,
                  count: totals.absent,
                ),
                _TotalPill(
                  status: AttendanceStatus.halfDay,
                  count: totals.halfDay,
                ),
                _TotalPill(status: AttendanceStatus.leave, count: totals.leave),
              ],
            ),
        ],
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({required this.status, required this.count});

  final AttendanceStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${status.label}: $count',
        style: context.text.labelMedium?.copyWith(
          color: status.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.record,
    required this.beforeJoining,
    required this.inFuture,
    required this.onTap,
  });

  final DateTime day;
  final AttendanceRecord? record;
  final bool beforeJoining;
  final bool inFuture;
  final void Function(DateTime day, AttendanceStatus? status, String? note)
  onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = beforeJoining || inFuture;
    final status = record?.status;
    final color = status?.color;

    return Tooltip(
      message:
          '${AppDate.display(day)}'
          '${status == null ? '' : ' · ${status.label}'}',
      child: InkWell(
        onTap: disabled ? null : () => onTap(day, status, record?.note),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.15) ?? Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(
              color: color?.withValues(alpha: 0.4) ?? context.hairline,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${day.day}',
                style: context.text.labelMedium?.copyWith(
                  color: disabled
                      ? context.mutedColor.withValues(alpha: 0.45)
                      : (color ?? context.colors.onSurface),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              if (status != null)
                Text(
                  status.shortCode,
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1,
                    color: color,
                  ),
                )
              else if (beforeJoining)
                Text(
                  '—',
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1,
                    color: context.mutedColor.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayEditResult {
  const _DayEditResult({required this.status, this.note});

  final AttendanceStatus? status;
  final String? note;
}

/// Bottom sheet for changing one day's status from the calendar.
class _DayStatusSheet extends StatefulWidget {
  const _DayStatusSheet({
    required this.employeeName,
    required this.day,
    required this.status,
    required this.note,
  });

  final String employeeName;
  final DateTime day;
  final AttendanceStatus? status;
  final String? note;

  @override
  State<_DayStatusSheet> createState() => _DayStatusSheetState();
}

class _DayStatusSheetState extends State<_DayStatusSheet> {
  late AttendanceStatus? _status = widget.status;
  late final TextEditingController _noteController = TextEditingController(
    text: widget.note ?? '',
  );

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppDate.displayLong(widget.day),
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(widget.employeeName, style: context.text.bodySmall),
              AppSpacing.gapLg,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final AttendanceStatus status in AttendanceStatus.values)
                    GestureDetector(
                      onTap: () => setState(() => _status = status),
                      child: Opacity(
                        opacity: _status == status ? 1 : 0.55,
                        child: StatusChip(status: status),
                      ),
                    ),
                ],
              ),
              AppSpacing.gapLg,
              TextField(
                controller: _noteController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  counterText: '',
                ),
              ),
              AppSpacing.gapLg,
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.status == null
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(const _DayEditResult(status: null)),
                      child: const Text('Clear'),
                    ),
                  ),
                  AppSpacing.wGapMd,
                  Expanded(
                    child: FilledButton(
                      onPressed: _status == null
                          ? null
                          : () => Navigator.of(context).pop(
                              _DayEditResult(
                                status: _status,
                                note: _noteController.text,
                              ),
                            ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
