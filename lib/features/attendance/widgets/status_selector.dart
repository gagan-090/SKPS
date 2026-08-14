import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/attendance_status.dart';

/// The four-option P / A / H / L selector. One tap, no dialog.
///
/// When [expand] is true the options share the full width, which keeps every
/// target well past 48dp — this is the control the owner hits dozens of times
/// each morning, often one-handed.
class StatusSelector extends StatelessWidget {
  const StatusSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.expand = true,
    this.height = 48,
    this.optionWidth = 44,
    this.showLabels = true,
  });

  final AttendanceStatus? selected;
  final ValueChanged<AttendanceStatus> onSelected;
  final bool enabled;
  final bool expand;
  final double height;

  /// Used only when [expand] is false.
  final double optionWidth;

  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;

    final options = <Widget>[
      for (final AttendanceStatus status in AttendanceStatus.values)
        _buildOption(
          status: status,
          showLeftBorder: status != AttendanceStatus.values.first,
        ),
    ];

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: AppRadius.buttonRadius,
          border: Border.all(color: divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            for (final Widget option in options)
              if (expand) Expanded(child: option) else option,
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required AttendanceStatus status,
    required bool showLeftBorder,
  }) {
    return _StatusOption(
      status: status,
      selected: selected == status,
      width: expand ? null : optionWidth,
      showLeftBorder: showLeftBorder,
      showLabel: showLabels,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onSelected(status);
            }
          : null,
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.width,
    required this.showLeftBorder,
    required this.showLabel,
    required this.onTap,
  });

  final AttendanceStatus status;
  final bool selected;
  final double? width;
  final bool showLeftBorder;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: status.label,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? status.color : Colors.transparent,
            border: Border(
              left: showLeftBorder
                  ? BorderSide(color: theme.dividerColor)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                status.shortCode,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
              if (showLabel)
                Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    height: 1.2,
                    color: foreground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
