import 'package:flutter/material.dart';

/// The app palette. Calm, high contrast, readable in bright sunlight.
class AppColors {
  const AppColors._();

  // ---- brand --------------------------------------------------------------
  static const Color primary = Color(0xFF1B4D3E);
  static const Color primaryContainer = Color(0xFFE3EFE9);
  static const Color primaryDark = Color(0xFF6FBFA1);
  static const Color primaryContainerDark = Color(0xFF14332A);

  // ---- light surfaces -----------------------------------------------------
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // ---- dark surfaces ------------------------------------------------------
  static const Color backgroundDark = Color(0xFF0F1115);
  static const Color surfaceDark = Color(0xFF181B21);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color dividerDark = Color(0xFF2A2F38);

  // ---- attendance status --------------------------------------------------
  static const Color present = Color(0xFF16A34A);
  static const Color absent = Color(0xFFDC2626);
  static const Color halfDay = Color(0xFFF59E0B);
  static const Color leave = Color(0xFF6366F1);
  static const Color notMarked = Color(0xFF9CA3AF);

  /// Deterministic avatar tints, picked by hashing the employee name so the
  /// same person always keeps the same colour.
  static const List<Color> avatarPalette = <Color>[
    Color(0xFF1B4D3E),
    Color(0xFF0E7490),
    Color(0xFF4338CA),
    Color(0xFF9D174D),
    Color(0xFF92400E),
    Color(0xFF3F6212),
    Color(0xFF6D28D9),
    Color(0xFF9F1239),
    Color(0xFF115E59),
    Color(0xFF1E40AF),
  ];

  static Color avatarFor(String seed) {
    if (seed.isEmpty) return avatarPalette.first;
    var hash = 0;
    for (final code in seed.trim().toLowerCase().codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return avatarPalette[hash % avatarPalette.length];
  }
}
