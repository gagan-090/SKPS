import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Fail loudly, and readably, rather than booting with an empty backend URL.
  if (!Env.isConfigured) {
    runApp(_StartupFailureApp(message: Env.missingConfigMessage));
    return;
  }

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Named `publishableKey` since supabase_flutter 2.17; the classic
      // `anon` JWT from the dashboard goes here unchanged.
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // Keeps the owner logged in across app restarts.
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (error) {
    runApp(
      _StartupFailureApp(
        message:
            'Could not start the app.\n\n'
            'Check that SUPABASE_URL and SUPABASE_ANON_KEY are correct.\n\n'
            '$error',
      ),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      // Surface failures immediately behind our own Retry buttons instead of
      // letting Riverpod silently re-attempt in the background.
      retry: (int retryCount, Object error) => null,
      child: const SkpsApp(),
    ),
  );
}

/// Shown when the app cannot boot at all. Deliberately dependency-free.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.settings_ethernet_rounded,
                    size: 44,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configuration problem',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
