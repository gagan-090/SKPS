import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/month_selector.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/employee.dart';
import '../employees/employees_controller.dart';
import '../settings/settings_controller.dart';
import 'export_service.dart';
import 'report_controller.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const double _rowHeight = 40;
  static const double _nameColumnWidth = 132;
  static const double _dayColumnWidth = 34;
  static const double _totalColumnWidth = 40;

  int? _year;
  int? _month;
  String? _employeeId;
  bool _exporting = false;

  int get year => _year ?? ref.read(prefsProvider).lastYear;
  int get month => _month ?? ref.read(prefsProvider).lastMonth;

  void _onMonthChanged(int year, int month) {
    setState(() {
      _year = year;
      _month = month;
    });
    ref.read(prefsProvider.notifier).setLastMonth(year, month);
  }

  Future<void> _export(
    ReportData data,
    Future<void> Function(ExportService service) run,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await run(ref.read(exportServiceProvider));
    } on AppException catch (error) {
      if (mounted) context.showFailure(error.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String? get _selectedEmployeeName {
    if (_employeeId == null) return null;
    return ref.read(employeeByIdProvider(_employeeId!))?.name;
  }

  @override
  Widget build(BuildContext context) {
    final query = (year: year, month: month, employeeId: _employeeId);
    final reportAsync = ref.watch(reportProvider(query));
    final employees = ref.watch(employeeListProvider).value ?? <Employee>[];
    final businessName = ref.watch(
      prefsProvider.select((AppPrefs p) => p.businessName),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          AppSpacing.wGapXs,
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: <Widget>[
                MonthSelector(
                  year: year,
                  month: month,
                  enabled: !_exporting,
                  onChanged: _onMonthChanged,
                ),
                AppSpacing.gapMd,
                _ScopeSelector(
                  employees: employees,
                  selectedId: _employeeId,
                  enabled: !_exporting,
                  onChanged: (String? id) => setState(() => _employeeId = id),
                ),
              ],
            ),
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const LoadingView(message: 'Building report…'),
              error: (Object error, StackTrace stack) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(reportProvider(query)),
              ),
              data: (ReportData data) {
                if (data.rows.isEmpty || data.isEmpty) {
                  return _EmptyReport(monthLabel: data.monthLabel);
                }
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _SummaryLine(data: data),
                            AppSpacing.gapMd,
                            _Matrix(
                              data: data,
                              rowHeight: _rowHeight,
                              nameColumnWidth: _nameColumnWidth,
                              dayColumnWidth: _dayColumnWidth,
                              totalColumnWidth: _totalColumnWidth,
                            ),
                            AppSpacing.gapMd,
                            const _Legend(),
                          ],
                        ),
                      ),
                    ),
                    _ExportBar(
                      exporting: _exporting,
                      onCsv: () => _export(
                        data,
                        (ExportService service) => service.shareCsv(
                          data,
                          employeeName: _selectedEmployeeName,
                          businessName: businessName,
                        ),
                      ),
                      onPdf: () => _export(
                        data,
                        (ExportService service) => service.sharePdf(
                          data,
                          businessName: businessName,
                          employeeName: _selectedEmployeeName,
                        ),
                      ),
                      onPrint: () => _export(
                        data,
                        (ExportService service) =>
                            service.printPdf(data, businessName: businessName),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.employees,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Employee> employees;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.filter_alt_outlined),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      onChanged: enabled ? onChanged : null,
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(child: Text('All employees')),
        for (final Employee employee in employees)
          DropdownMenuItem<String?>(
            value: employee.id,
            child: Text(
              employee.isActive ? employee.name : '${employee.name} (inactive)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${data.rows.length} ${data.rows.length == 1 ? 'employee' : 'employees'} · '
      '${data.daysMarked} of ${data.daysInMonth} days marked',
      style: context.text.bodySmall,
    );
  }
}

/// Horizontally scrollable matrix with a frozen name column.
class _Matrix extends StatelessWidget {
  const _Matrix({
    required this.data,
    required this.rowHeight,
    required this.nameColumnWidth,
    required this.dayColumnWidth,
    required this.totalColumnWidth,
  });

  final ReportData data;
  final double rowHeight;
  final double nameColumnWidth;
  final double dayColumnWidth;
  final double totalColumnWidth;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Frozen first column.
          SizedBox(
            width: nameColumnWidth,
            child: Column(
              children: <Widget>[
                _cell(
                  context,
                  child: Text('Employee', style: context.text.labelSmall),
                  align: Alignment.centerLeft,
                  header: true,
                ),
                for (final ReportRow row in data.rows)
                  _cell(
                    context,
                    align: Alignment.centerLeft,
                    child: Text(
                      row.employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.hairline),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      for (int day = 1; day <= data.daysInMonth; day++)
                        SizedBox(
                          width: dayColumnWidth,
                          child: _cell(
                            context,
                            header: true,
                            child: Text('$day', style: context.text.labelSmall),
                          ),
                        ),
                      for (final String label in const <String>[
                        'P',
                        'A',
                        'H',
                        'L',
                        'Days',
                      ])
                        SizedBox(
                          width: totalColumnWidth,
                          child: _cell(
                            context,
                            header: true,
                            child: Text(
                              label,
                              style: context.text.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final ReportRow row in data.rows)
                    Row(
                      children: <Widget>[
                        for (int day = 1; day <= data.daysInMonth; day++)
                          SizedBox(
                            width: dayColumnWidth,
                            child: _dayCell(context, row, day),
                          ),
                        _totalCell(context, '${row.totals.present}'),
                        _totalCell(context, '${row.totals.absent}'),
                        _totalCell(context, '${row.totals.halfDay}'),
                        _totalCell(context, '${row.totals.leave}'),
                        _totalCell(
                          context,
                          '${row.totals.totalMarked}',
                          bold: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context, {
    required Widget child,
    Alignment align = Alignment.center,
    bool header = false,
  }) {
    return Container(
      height: rowHeight,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: header ? context.colors.surfaceContainerHigh : null,
        border: Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: child,
    );
  }

  Widget _dayCell(BuildContext context, ReportRow row, int day) {
    final record = row.byDay[day];
    final before =
        record == null && row.isBeforeJoining(data.year, data.month, day);

    return _cell(
      context,
      child: record == null
          ? Text(
              before ? '—' : '',
              style: context.text.labelSmall?.copyWith(
                color: context.mutedColor.withValues(alpha: 0.6),
              ),
            )
          : StatusCell(status: record.status, size: 26),
    );
  }

  Widget _totalCell(BuildContext context, String value, {bool bold = false}) {
    return SizedBox(
      width: totalColumnWidth,
      child: _cell(
        context,
        child: Text(
          value,
          style: context.text.labelMedium?.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final AttendanceStatus status in AttendanceStatus.values)
          StatusChip(status: status, dense: true),
        Text(
          '—  before joining',
          style: context.text.labelSmall?.copyWith(color: context.mutedColor),
        ),
      ],
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({
    required this.exporting,
    required this.onCsv,
    required this.onPdf,
    required this.onPrint,
  });

  final bool exporting;
  final VoidCallback onCsv;
  final VoidCallback onPdf;
  final VoidCallback onPrint;

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
              child: SecondaryButton(
                label: 'CSV',
                icon: Icons.table_chart_outlined,
                onPressed: exporting ? null : onCsv,
              ),
            ),
            AppSpacing.wGapMd,
            Expanded(
              child: PrimaryButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                loading: exporting,
                onPressed: onPdf,
              ),
            ),
            AppSpacing.wGapSm,
            IconButton(
              tooltip: 'Print / Save as PDF',
              onPressed: exporting ? null : onPrint,
              icon: const Icon(Icons.print_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.insert_chart_outlined,
      title: 'Nothing to report',
      message:
          'No attendance was recorded in $monthLabel. Mark a few days and the '
          'report will appear here.',
      actionLabel: 'Mark Attendance',
      onAction: () => context.push(AppRoutes.attendance),
    );
  }
}
