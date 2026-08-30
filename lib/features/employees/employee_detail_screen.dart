import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
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
    double? amount,
  ) async {
    final result = await showModalBottomSheet<_DayEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _DayStatusSheet(
        employeeName: employee.name,
        perDaySalary: employee.hasSalary ? employee.perDaySalary : null,
        day: day,
        status: current,
        note: note,
        amount: amount,
      ),
    );
    if (result == null || !mounted) return;

    final error = await updateSingleDay(
      ref,
      employeeId: employee.id,
      day: day,
      status: result.status,
      note: result.note,
      amount: result.amount,
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

  /// Opens the inline salary editor and saves the change to the roster.
  Future<void> _editSalary(Employee employee) async {
    final result = await showModalBottomSheet<_SalaryResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _SalarySheet(employee: employee),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(employeeListProvider.notifier)
          .updateEmployee(
            employee.copyWith(
              salaryType: result.amount == null
                  ? employee.salaryType
                  : result.type,
              salaryAmount: result.amount,
              clearSalary: result.amount == null,
            ),
          );
      if (!mounted) return;
      context.showSuccess(
        result.amount == null ? 'Salary removed' : 'Salary updated',
      );
    } on AppException catch (error) {
      if (!mounted) return;
      context.showFailure(error.message);
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
            onEditSalary: () => _editSalary(employee),
            onEditDay:
                (
                  DateTime day,
                  AttendanceStatus? status,
                  String? note,
                  double? amount,
                ) => _editDay(employee, day, status, note, amount),
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
    required this.onEditSalary,
    required this.onEditDay,
  });

  final Employee employee;
  final int year;
  final int month;
  final void Function(int year, int month) onMonthChanged;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onEditSalary;
  final void Function(
    DateTime day,
    AttendanceStatus? status,
    String? note,
    double? amount,
  )
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
        _SalaryCard(employee: employee, onEdit: onEditSalary),
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

/// The editable Salary section: shows the rate, or an "Add salary" prompt.
class _SalaryCard extends StatelessWidget {
  const _SalaryCard({required this.employee, required this.onEdit});

  final Employee employee;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final has = employee.hasSalary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Salary', style: context.text.titleMedium),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(
                  has ? Icons.edit_outlined : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(has ? 'Edit' : 'Add salary'),
              ),
            ],
          ),
          if (has) ...<Widget>[
            AppSpacing.gapSm,
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: AppRadius.buttonRadius,
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
                AppSpacing.wGapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${Money.format(employee.perDaySalary)} / day',
                        style: context.text.titleLarge?.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee.salaryType == SalaryType.monthly
                            ? '${Money.format(employee.monthlySalary)} per month'
                            : '≈ ${Money.format(employee.monthlySalary)} per month',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            AppSpacing.gapXs,
            Text(
              'No salary set yet. Add a daily or monthly wage to see this '
              "person's pay in reports.",
              style: context.text.bodyMedium?.copyWith(
                color: context.mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Result of the salary editor. A null [amount] means "remove the salary".
class _SalaryResult {
  const _SalaryResult({required this.type, required this.amount});

  final SalaryType type;
  final double? amount;
}

/// Bottom sheet to add or change an employee's salary from the detail screen.
class _SalarySheet extends StatefulWidget {
  const _SalarySheet({required this.employee});

  final Employee employee;

  @override
  State<_SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends State<_SalarySheet> {
  late SalaryType _type = widget.employee.salaryType;
  late final TextEditingController _controller = TextEditingController(
    text: widget.employee.salaryAmount == null
        ? ''
        : Money.plain(widget.employee.salaryAmount!).replaceAll(',', ''),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _hint {
    final amount = Validators.parseAmount(_controller.text);
    if (amount == null || amount <= 0) return null;
    return _type == SalaryType.monthly
        ? '≈ ${Money.format(amount / Employee.daysInSalaryMonth)} per day'
        : '≈ ${Money.format(amount * Employee.daysInSalaryMonth)} per month';
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
              Text('Salary', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(widget.employee.name, style: context.text.bodySmall),
              AppSpacing.gapLg,
              SegmentedButton<SalaryType>(
                showSelectedIcon: false,
                segments: <ButtonSegment<SalaryType>>[
                  for (final SalaryType type in SalaryType.values)
                    ButtonSegment<SalaryType>(
                      value: type,
                      label: Text(type.label),
                    ),
                ],
                selected: <SalaryType>{_type},
                onSelectionChanged: (Set<SalaryType> selection) =>
                    setState(() => _type = selection.first),
              ),
              AppSpacing.gapLg,
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _type == SalaryType.monthly
                      ? 'Monthly salary'
                      : 'Per-day salary',
                  prefixText: '₹ ',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  helperText: _hint ?? 'Leave blank to skip',
                ),
              ),
              AppSpacing.gapLg,
              Row(
                children: <Widget>[
                  if (widget.employee.hasSalary) ...<Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(
                          const _SalaryResult(
                            type: SalaryType.perDay,
                            amount: null,
                          ),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                    AppSpacing.wGapMd,
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _SalaryResult(
                          type: _type,
                          amount: Validators.parseAmount(_controller.text),
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
  final void Function(
    DateTime day,
    AttendanceStatus? status,
    String? note,
    double? amount,
  )
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
  final void Function(
    DateTime day,
    AttendanceStatus? status,
    String? note,
    double? amount,
  )
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
        onTap: disabled
            ? null
            : () => onTap(day, status, record?.note, record?.amount),
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
  const _DayEditResult({required this.status, this.note, this.amount});

  final AttendanceStatus? status;
  final String? note;
  final double? amount;
}

/// Bottom sheet for changing one day's status from the calendar.
class _DayStatusSheet extends StatefulWidget {
  const _DayStatusSheet({
    required this.employeeName,
    required this.perDaySalary,
    required this.day,
    required this.status,
    required this.note,
    required this.amount,
  });

  final String employeeName;

  /// The employee's daily rate, or null when no salary is on file.
  final double? perDaySalary;
  final DateTime day;
  final AttendanceStatus? status;
  final String? note;
  final double? amount;

  @override
  State<_DayStatusSheet> createState() => _DayStatusSheetState();
}

class _DayStatusSheetState extends State<_DayStatusSheet> {
  late AttendanceStatus? _status = widget.status;
  late final TextEditingController _noteController = TextEditingController(
    text: widget.note ?? '',
  );
  late final TextEditingController _amountController = TextEditingController(
    text: widget.amount == null
        ? ''
        : Money.plain(widget.amount!).replaceAll(',', ''),
  );

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? get _amountHint {
    final status = _status;
    final rate = widget.perDaySalary;
    if (status == null || rate == null) return null;
    return 'Default ${Money.format(rate * status.dayValue)} · edit to override';
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
              if (_status != null) ...<Widget>[
                AppSpacing.gapMd,
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount (optional)',
                    prefixText: '₹ ',
                    helperText: _amountHint,
                  ),
                ),
              ],
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
                                amount: Validators.parseAmount(
                                  _amountController.text,
                                ),
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
