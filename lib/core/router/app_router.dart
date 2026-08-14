import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/attendance/mark_attendance_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/home_screen.dart';
import '../../features/employees/employee_detail_screen.dart';
import '../../features/employees/employee_form_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/reports/report_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../utils/date_utils.dart';
import 'scaffold_with_nav.dart';

/// Every path in the app, in one place.
class AppRoutes {
  const AppRoutes._();

  static const String login = '/login';
  static const String home = '/home';
  static const String employees = '/employees';
  static const String employeeNew = '/employees/new';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String attendance = '/attendance';

  static String employeeDetail(String id) => '/employees/$id';
  static String employeeEdit(String id) => '/employees/$id/edit';

  /// `/attendance?date=YYYY-MM-DD`
  static String attendanceFor(DateTime day) =>
      '$attendance?date=${AppDate.ymd(day)}';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'home',
);
final GlobalKey<NavigatorState> _employeesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'employees');
final GlobalKey<NavigatorState> _reportsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'reports');

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefreshNotifier(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn = auth.isLoggedIn;
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      // Session missing or expired: everything funnels back to Login.
      if (!loggedIn) return goingToLogin ? null : AppRoutes.login;
      if (goingToLogin) return AppRoutes.home;
      return null;
    },
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteErrorScreen(location: state.uri.toString()),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.attendance,
        name: 'attendance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final raw = state.uri.queryParameters['date'];
          final day = raw == null ? AppDate.today() : AppDate.parseYmd(raw);
          return MarkAttendanceScreen(initialDay: day);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => ScaffoldWithNav(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _employeesNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.employees,
                name: 'employees',
                builder: (BuildContext context, GoRouterState state) =>
                    const EmployeesScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    name: 'employeeNew',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        const EmployeeFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'employeeDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        EmployeeDetailScreen(
                          employeeId: state.pathParameters['id']!,
                        ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        name: 'employeeEdit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) =>
                            EmployeeFormScreen(
                              employeeId: state.pathParameters['id'],
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _reportsNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.reports,
                name: 'reports',
                builder: (BuildContext context, GoRouterState state) =>
                    const ReportScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Supabase auth events into something `GoRouter` can listen to.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.asBroadcastStream().listen(
      (AuthState _) => notifyListeners(),
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'No screen matches "$location".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
