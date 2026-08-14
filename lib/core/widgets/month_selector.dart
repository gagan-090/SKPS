import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import '../utils/date_utils.dart';

/// Month + year stepper used by Reports and the employee calendar.
/// Never steps past the current month.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.year,
    required this.month,
    required this.onChanged,
    this.enabled = true,
  });

  final int year;
  final int month;
  final void Function(int year, int month) onChanged;
  final bool enabled;

  bool get _canGoForward {
    final now = DateTime.now();
    return year < now.year || (year == now.year && month < now.month);
  }

  void _step(int delta) {
    HapticFeedback.selectionClick();
    final target = DateTime(year, month + delta);
    onChanged(target.year, target.month);
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext ctx) => _MonthPickerDialog(
        initialYear: year,
        initialMonth: month,
        maxYear: now.year,
        maxMonth: now.month,
      ),
    );
    if (picked == null) return;
    onChanged(picked.year, picked.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Previous month',
            onPressed: enabled ? () => _step(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              onTap: enabled ? () => _pick(context) : null,
              borderRadius: AppRadius.buttonRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  AppDate.monthYear(year, month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: enabled && _canGoForward ? () => _step(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.maxYear,
    required this.maxMonth,
  });

  final int initialYear;
  final int initialMonth;
  final int maxYear;
  final int maxMonth;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initialYear;

  bool _isSelectable(int month) =>
      _year < widget.maxYear ||
      (_year == widget.maxYear && month <= widget.maxMonth);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Previous year',
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '$_year',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Next year',
            onPressed: _year >= widget.maxYear
                ? null
                : () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 2.1,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: <Widget>[
            for (int month = 1; month <= 12; month++)
              _MonthChoice(
                label: AppDate.monthAbbr(month),
                selected:
                    month == widget.initialMonth && _year == widget.initialYear,
                enabled: _isSelectable(month),
                onTap: () => Navigator.of(context).pop(DateTime(_year, month)),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MonthChoice extends StatelessWidget {
  const _MonthChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: AppRadius.buttonRadius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.buttonRadius,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonRadius,
            border: Border.all(color: theme.dividerColor),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled
                  ? (selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface)
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
