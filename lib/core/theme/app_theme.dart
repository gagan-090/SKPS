import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Light and dark themes.
///
/// House style: elevation 0 everywhere, hairline borders instead of shadows,
/// generous tap targets, tabular figures wherever numbers line up in columns.
class AppTheme {
  const AppTheme._();

  static ThemeData light([AppBrand brand = AppBrand.classic]) =>
      _build(Brightness.light, BrandPalette.of(brand));

  static ThemeData dark([AppBrand brand = AppBrand.classic]) =>
      _build(Brightness.dark, BrandPalette.of(brand));

  static ThemeData _build(Brightness brightness, BrandPalette brand) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? AppColors.backgroundDark : AppColors.background;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final divider = isDark ? AppColors.dividerDark : AppColors.divider;
    final primary = isDark ? brand.primaryDark : brand.primary;
    final primaryContainer = isDark
        ? brand.primaryContainerDark
        : brand.primaryContainer;
    final onPrimary = isDark ? brand.onPrimaryDark : brand.onPrimary;
    final onPrimaryContainer = isDark ? brand.primaryDark : brand.primary;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: primaryContainer,
      onSecondaryContainer: onPrimaryContainer,
      error: AppColors.absent,
      onError: Colors.white,
      errorContainer: isDark
          ? const Color(0xFF3B1416)
          : const Color(0xFFFEE2E2),
      onErrorContainer: isDark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFF991B1B),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerLowest: isDark ? const Color(0xFF0B0D11) : Colors.white,
      surfaceContainerLow: background,
      surfaceContainer: isDark
          ? const Color(0xFF1E222A)
          : const Color(0xFFF2F4F7),
      surfaceContainerHigh: isDark
          ? const Color(0xFF232830)
          : const Color(0xFFEDF0F4),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2A2F38)
          : const Color(0xFFE8EBF0),
      onSurfaceVariant: textSecondary,
      outline: divider,
      outlineVariant: divider,
      inverseSurface: isDark ? AppColors.surface : AppColors.textPrimary,
      onInverseSurface: isDark ? AppColors.textPrimary : Colors.white,
      inversePrimary: isDark ? brand.primary : brand.primaryDark,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final baseText = isDark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    final textTheme = GoogleFonts.interTextTheme(
      baseText,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    final shapedText = textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.4),
      bodySmall: textTheme.bodySmall?.copyWith(
        color: textSecondary,
        height: 1.35,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: shapedText,
      dividerColor: divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: shapedText.titleLarge?.copyWith(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: divider),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: shapedText.labelLarge?.copyWith(fontSize: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: primary,
          side: BorderSide(color: divider),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: shapedText.labelLarge?.copyWith(fontSize: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primary,
          textStyle: shapedText.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: shapedText.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: shapedText.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle: shapedText.bodyMedium?.copyWith(color: primary),
        prefixStyle: shapedText.bodyLarge?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.absent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.absent, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryContainer,
        side: BorderSide(color: divider),
        labelStyle: shapedText.labelLarge,
        secondaryLabelStyle: shapedText.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
        showCheckmark: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => shapedText.labelMedium!.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? onPrimaryContainer
                : textSecondary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: shapedText.titleLarge,
        contentTextStyle: shapedText.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF2A2F38)
            : AppColors.textPrimary,
        contentTextStyle: shapedText.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: brand.primaryDark,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonRadius,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonRadius,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: shapedText.titleMedium,
        subtitleTextStyle: shapedText.bodySmall,
        minVerticalPadding: AppSpacing.md,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: divider,
        circularTrackColor: Colors.transparent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(shapedText.labelLarge),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF06231A) : Colors.white)
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2F38) : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        textStyle: shapedText.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

/// Convenience accessors used throughout the widget tree.
extension AppThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Secondary/muted text colour.
  Color get mutedColor => Theme.of(this).colorScheme.onSurfaceVariant;

  /// Hairline border colour used on cards and dividers.
  Color get hairline => Theme.of(this).dividerColor;
}
