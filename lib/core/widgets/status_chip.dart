import 'package:flutter/material.dart';

import '../../data/models/attendance_status.dart';
import '../theme/app_spacing.dart';

/// A pill showing an attendance status, tinted with the status colour.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.dense = false,
    this.showLabel = true,
  });

  final AttendanceStatus status;
  final bool dense;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status.color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        showLabel ? status.label : status.shortCode,
        style:
            (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The small square used in calendars and the report matrix.
class StatusCell extends StatelessWidget {
  const StatusCell({
    super.key,
    required this.status,
    this.size = 32,
    this.label,
    this.dimmed = false,
    this.onTap,
  });

  /// Null renders the "not marked" cell.
  final AttendanceStatus? status;
  final double size;
  final String? label;

  /// Used for days before the employee joined — shown as an em dash.
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status?.color;

    final content = Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            color?.withValues(alpha: 0.14) ??
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(
          color: color?.withValues(alpha: 0.4) ?? theme.dividerColor,
        ),
      ),
      child: Text(
        label ?? (dimmed ? '—' : status?.shortCode ?? ''),
        style: theme.textTheme.labelMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: content,
    );
  }
}
