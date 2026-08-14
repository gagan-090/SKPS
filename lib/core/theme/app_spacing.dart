import 'package:flutter/material.dart';

/// 4pt spacing scale and the shape tokens used across the app.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard horizontal screen padding.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);

  /// Standard card padding.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Vertical rhythm between stacked cards.
  static const SizedBox gapCards = SizedBox(height: md);

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);

  static const SizedBox wGapXs = SizedBox(width: xs);
  static const SizedBox wGapSm = SizedBox(width: sm);
  static const SizedBox wGapMd = SizedBox(width: md);
  static const SizedBox wGapLg = SizedBox(width: lg);
}

/// Corner radii. Cards 16, buttons 12, chips fully rounded.
class AppRadius {
  const AppRadius._();

  static const double card = 16;
  static const double button = 12;
  static const double field = 12;
  static const double sheet = 20;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
