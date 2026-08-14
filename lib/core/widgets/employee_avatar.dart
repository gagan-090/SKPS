import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular initials avatar. The colour is derived from the name, so the same
/// employee always looks the same without storing anything.
class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.inactive = false,
  });

  final String name;
  final double size;
  final bool inactive;

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final single = parts.first;
      return (single.length == 1 ? single : single.substring(0, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.avatarFor(name);
    final color = inactive ? AppColors.notMarked : base;

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        initialsOf(name),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
