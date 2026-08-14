import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Injected in `main()` once the instance has been loaded, so the rest of the
/// app can read preferences synchronously.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in main()',
      ),
    );

/// Locally stored owner preferences. Nothing here is sensitive.
class AppPrefs {
  const AppPrefs({
    required this.themeMode,
    required this.businessName,
    required this.lastYear,
    required this.lastMonth,
  });

  final ThemeMode themeMode;

  /// Printed as the title of exported PDFs.
  final String businessName;

  /// The month the owner last looked at in Reports.
  final int lastYear;
  final int lastMonth;

  AppPrefs copyWith({
    ThemeMode? themeMode,
    String? businessName,
    int? lastYear,
    int? lastMonth,
  }) {
    return AppPrefs(
      themeMode: themeMode ?? this.themeMode,
      businessName: businessName ?? this.businessName,
      lastYear: lastYear ?? this.lastYear,
      lastMonth: lastMonth ?? this.lastMonth,
    );
  }
}

class PrefsController extends Notifier<AppPrefs> {
  static const String _kThemeMode = 'theme_mode';
  static const String _kBusinessName = 'business_name';
  static const String _kLastYear = 'last_year';
  static const String _kLastMonth = 'last_month';

  static const String defaultBusinessName = 'My Business';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final now = DateTime.now();
    return AppPrefs(
      themeMode: _themeFromString(prefs.getString(_kThemeMode)),
      businessName: prefs.getString(_kBusinessName)?.trim().isNotEmpty ?? false
          ? prefs.getString(_kBusinessName)!.trim()
          : defaultBusinessName,
      lastYear: prefs.getInt(_kLastYear) ?? now.year,
      lastMonth: prefs.getInt(_kLastMonth) ?? now.month,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setBusinessName(String name) async {
    final trimmed = name.trim().isEmpty ? defaultBusinessName : name.trim();
    state = state.copyWith(businessName: trimmed);
    await _prefs.setString(_kBusinessName, trimmed);
  }

  Future<void> setLastMonth(int year, int month) async {
    if (state.lastYear == year && state.lastMonth == month) return;
    state = state.copyWith(lastYear: year, lastMonth: month);
    await _prefs.setInt(_kLastYear, year);
    await _prefs.setInt(_kLastMonth, month);
  }

  static ThemeMode _themeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

final NotifierProvider<PrefsController, AppPrefs> prefsProvider =
    NotifierProvider<PrefsController, AppPrefs>(PrefsController.new);
