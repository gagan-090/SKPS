import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/month_selector.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/attendance_status.dart';
import '../settings/settings_controller.dart';
import 'export_service.dart';
import 'report_controller.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const double _rowHeight = 44;
  static const double _nameColumnWidth = 180;
  static const double _dayColumnWidth = 34;
  static const double _totalColumnWidth = 40;

  int? _year;
  int? _month;

  /// Employee ids ticked for export. null means "everyone in the report".
  Set<String>? _selectedIds;
  bool _exporting = false;

  int get year => _year ?? ref.read(prefsProvider).lastYear;
  int get month => _month ?? ref.read(prefsProvider).lastMonth;

  void _onMonthChanged(int year, int month) {
    setState(() {
      _year = year;
      _month = month;
      // A new month has a new roster; start with everyone ticked again.
      _selectedIds = null;
    });
    ref.read(prefsProvider.notifier).setLastMonth(year, month);
  }

  /// The ids actually ticked, resolving the "everyone" default against [data].
  Set<String> _selection(ReportData data) =>
      _selectedIds ??
      <String>{for (final ReportRow row in data.rows) row.employee.id};

  void _toggle(ReportData data, String id) {
    final next = <String>{..._selection(data)};
    if (!next.remove(id)) next.add(id);
    setState(() => _selectedIds = next);
  }

  void _toggleAll(ReportData data, bool selectAll) {
    setState(() => _selectedIds = selectAll ? null : <String>{});
  }

  Future<void> _export(
    ReportData data,
    Future<void> Function(ExportService service, ReportData subset) run,
  ) async {
    if (_exporting) return;
    final selected = _selection(data);
    if (selected.isEmpty) {
      context.showFailure('Tick at least one employee to export.');
      return;
    }
    final subset = data.withEmployees(selected);
    setState(() => _exporting = true);
    try {
      await run(ref.read(exportServiceProvider), subset);
    } on AppException catch (error) {
      if (mounted) context.showFailure(error.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// A single ticked employee names the export file; a subset stays generic.
  String? _exportName(ReportData data) {
    final selected = _selection(data);
    if (selected.length != 1) return null;
    for (final ReportRow row in data.rows) {
      if (row.employee.id == selected.first) return row.employee.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final query = (year: year, month: month, employeeId: null);
    final reportAsync = ref.watch(reportProvider(query));
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
            child: MonthSelector(
              year: year,
              month: month,
              enabled: !_exporting,
              onChanged: _onMonthChanged,
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
                            _SummaryLine(
                              data: data,
                              selectedCount: _selection(data).length,
                            ),
                            AppSpacing.gapMd,
                            _Matrix(
                              data: data,
                              rowHeight: _rowHeight,
                              nameColumnWidth: _nameColumnWidth,
                              dayColumnWidth: _dayColumnWidth,
                              totalColumnWidth: _totalColumnWidth,
                              isSelected: (String id) => _selection(data).contains(id),
                              onToggle: (String id) => _toggle(data, id),
                              onToggleAll: (bool all) => _toggleAll(data, all),
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
                        (ExportService service, ReportData subset) =>
                            service.shareCsv(
                              subset,
                              employeeName: _exportName(data),
                              businessName: businessName,
                            ),
                      ),
                      onPdf: () => _export(
                        data,
                        (ExportService service, ReportData subset) =>
                            service.sharePdf(
                              subset,
                              businessName: businessName,
                              employeeName: _exportName(data),
                            ),
                      ),
                      onPrint: () => _export(
                        data,
                        (ExportService service, ReportData subset) =>
                            service.printPdf(subset, businessName: businessName),
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.data, required this.selectedCount});

  final ReportData data;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$selectedCount of ${data.rows.length} '
          '${data.rows.length == 1 ? 'employee' : 'employees'} ticked · '
          '${data.daysMarked} of ${data.daysInMonth} days marked',
          style: context.text.bodySmall,
        ),
        if (data.hasSalary) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            'Total pay ${Money.format(data.totalSalary)}',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Horizontally scrollable matrix with a frozen name column. Each employee has
/// a tickbox in that frozen column; only ticked rows are exported.
class _Matrix extends StatelessWidget {
  const _Matrix({
    required this.data,
    required this.rowHeight,
    required this.nameColumnWidth,
    required this.dayColumnWidth,
    required this.totalColumnWidth,
    required this.isSelected,
    required this.onToggle,
    required this.onToggleAll,
  });

  static const double _salaryColumnWidth = 78;

  final ReportData data;
  final double rowHeight;
  final double nameColumnWidth;
  final double dayColumnWidth;
  final double totalColumnWidth;
  final bool Function(String id) isSelected;
  final ValueChanged<String> onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final int selectedCount =
        data.rows.where((ReportRow r) => isSelected(r.employee.id)).length;
    final bool allSelected =
        data.rows.isNotEmpty && selectedCount == data.rows.length;
    final bool? headerValue = allSelected
        ? true
        : (selectedCount == 0 ? false : null);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Frozen first column: tickbox + name.
          SizedBox(
            width: nameColumnWidth,
            child: Column(
              children: <Widget>[
                _cell(
                  context,
                  align: Alignment.centerLeft,
                  header: true,
                  child: Row(
                    children: <Widget>[
                      _checkbox(
                        value: headerValue,
                        tristate: true,
                        onChanged: () => onToggleAll(!allSelected),
                      ),
                      Flexible(
                        child: Text('Employee', style: context.text.labelSmall),
                      ),
                    ],
                  ),
                ),
                for (final ReportRow row in data.rows)
                  _cell(
                    context,
                    align: Alignment.centerLeft,
                    child: Row(
                      children: <Widget>[
                        _checkbox(
                          value: isSelected(row.employee.id),
                          onChanged: () => onToggle(row.employee.id),
                        ),
                        Expanded(
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
                      SizedBox(
                        width: _salaryColumnWidth,
                        child: _cell(
                          context,
                          header: true,
                          child: Text(
                            'Salary',
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
                        SizedBox(
                          width: _salaryColumnWidth,
                          child: _cell(
                            context,
                            child: Text(
                              row.hasSalary ? Money.format(row.monthSalary) : '—',
                              style: context.text.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: row.hasSalary
                                    ? context.colors.onSurface
                                    : context.mutedColor,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
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

  Widget _checkbox({
    required bool? value,
    required VoidCallback onChanged,
    bool tristate = false,
  }) {
    return Checkbox(
      value: value,
      tristate: tristate,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: (_) => onChanged(),
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
