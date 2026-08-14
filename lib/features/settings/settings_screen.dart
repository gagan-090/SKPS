import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_info.dart';
import '../../core/errors/app_exception.dart';
import '../../core/router/app_router.dart';
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
