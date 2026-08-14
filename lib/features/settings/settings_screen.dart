import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_info.dart';
import '../../core/errors/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../data/repositories/auth_repository.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  Future<void> _editBusinessName(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Business name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Shown on exported reports',
          ),
          onSubmitted: (String value) => Navigator.of(ctx).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || !mounted) return;
    await ref.read(prefsProvider.notifier).setBusinessName(name);
    if (!mounted) return;
    context.showSuccess('Business name updated');
  }

  Future<void> _logout() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Log out?',
      message:
          'You will need your email and password to get back in. Attendance '
          'already saved stays on the server.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      context.showFailure(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final email = ref.watch(authRepositoryProvider).currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Business name'),
                  subtitle: Text(prefs.businessName),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editBusinessName(prefs.businessName),
                ),
                Divider(color: context.hairline),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Signed in as'),
                  subtitle: Text(email ?? 'Unknown'),
                ),
              ],
            ),
          ),
          AppSpacing.gapCards,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: 'Appearance'),
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: <ThemeMode>{prefs.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<ThemeMode> selection) => ref
                      .read(prefsProvider.notifier)
                      .setThemeMode(selection.first),
                ),
                AppSpacing.gapLg,
                Text('Colour', style: context.text.titleSmall),
                AppSpacing.gapXs,
                Text(
                  'SKPS paints the app in the colours of the SKPS logo.',
                  style: context.text.bodySmall,
                ),
                AppSpacing.gapMd,
                Row(
                  children: <Widget>[
                    for (final AppBrand brand in AppBrand.values) ...<Widget>[
                      Expanded(
                        child: _BrandButton(
                          brand: brand,
                          selected: prefs.brand == brand,
                          onTap: () =>
                              ref.read(prefsProvider.notifier).setBrand(brand),
                        ),
                      ),
                      if (brand != AppBrand.values.last) AppSpacing.wGapMd,
                    ],
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapCards,
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('App version'),
                  subtitle: const Text(AppInfo.versionLabel),
                ),
                Divider(color: context.hairline),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.logout_rounded,
                    color: context.colors.error,
                  ),
                  title: Text(
                    'Log out',
                    style: TextStyle(color: context.colors.error),
                  ),
                  trailing: _signingOut
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _signingOut ? null : _logout,
                ),
              ],
            ),
          ),
          AppSpacing.gapXl,
          Text(
            AppInfo.tagline,
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One colour-skin choice. Shows the swatch it applies, and the SKPS mark on
/// the SKPS option so the owner can see it is the logo's own blue.
class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.brand,
    required this.selected,
    required this.onTap,
  });

  final AppBrand brand;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BrandPalette.of(brand);
    final swatch = context.isDarkMode ? palette.primaryDark : palette.primary;

    return Material(
      color: selected
          ? (context.isDarkMode
                ? palette.primaryContainerDark
                : palette.primaryContainer)
          : Colors.transparent,
      borderRadius: AppRadius.buttonRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonRadius,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonRadius,
            border: Border.all(
              color: selected ? swatch : context.hairline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (brand == AppBrand.skps)
                Image.asset(AppInfo.logoAsset, height: 24, width: 24)
              else
                Container(
                  height: 20,
                  width: 20,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                  ),
                ),
              AppSpacing.wGapSm,
              Flexible(
                child: Text(
                  brand.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: selected ? swatch : context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected) ...<Widget>[
                AppSpacing.wGapXs,
                Icon(Icons.check_rounded, size: 18, color: swatch),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
