import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/employee.dart';
import 'employees_controller.dart';
import 'widgets/employee_tile.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String _query = '';
  EmployeeFilter _filter = EmployeeFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  Future<void> _openQuickActions(Employee employee) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) =>
          _QuickActionsSheet(employee: employee),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          AppSpacing.wGapXs,
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.employeeNew),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or mobile',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _debounce?.cancel();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.screen,
              itemCount: EmployeeFilter.values.length,
              separatorBuilder: (_, _) => AppSpacing.wGapSm,
              itemBuilder: (BuildContext context, int index) {
                final filter = EmployeeFilter.values[index];
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: _filter == filter,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = filter);
                  },
                );
              },
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: employeesAsync.when(
              loading: () => const ListSkeleton(),
              error: (Object error, StackTrace stack) => ErrorView(
                error: error,
                onRetry: () =>
                    ref.read(employeeListProvider.notifier).refresh(),
              ),
              data: (List<Employee> employees) {
                final visible = filterEmployees(
                  employees,
                  query: _query,
                  filter: _filter,
                );

                if (employees.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No employees yet',
                    message:
                        'Add the people who work with you, then start marking '
                        'attendance every day.',
                    actionLabel: 'Add Employee',
                    onAction: () => context.push(AppRoutes.employeeNew),
                  );
                }

                if (visible.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    compact: true,
                    title: 'No matches',
                    message: _query.isEmpty
                        ? 'No ${_filter.label.toLowerCase()} employees.'
                        : 'Nothing found for "$_query".',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(employeeListProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      96,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => AppSpacing.gapCards,
                    itemBuilder: (BuildContext context, int index) {
                      final employee = visible[index];
                      return EmployeeTile(
                        employee: employee,
                        onTap: () =>
                            context.push(AppRoutes.employeeDetail(employee.id)),
                        onLongPress: () => _openQuickActions(employee),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Long-press actions: Call, WhatsApp, Edit, Activate/Deactivate.
class _QuickActionsSheet extends ConsumerWidget {
  const _QuickActionsSheet({required this.employee});

  final Employee employee;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final deactivating = employee.isActive;
    final confirmed = await AppDialogs.confirm(
      context,
      title: deactivating ? 'Deactivate employee?' : 'Reactivate employee?',
      message: deactivating
          ? '${employee.name} will be hidden from Mark Attendance. Past '
                'attendance stays in your reports.'
          : '${employee.name} will appear in Mark Attendance again.',
      confirmLabel: deactivating ? 'Deactivate' : 'Reactivate',
      destructive: deactivating,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(employeeListProvider.notifier)
          .setActive(employee.id, isActive: !employee.isActive);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      context.showSuccess(
        deactivating ? 'Employee deactivated' : 'Employee reactivated',
      );
    } on AppException catch (error) {
      if (!context.mounted) return;
      context.showFailure(error.message);
    }
  }

  Future<void> _contact(
    BuildContext context,
    Future<bool> Function() action,
    String failureMessage,
  ) async {
    final launched = await action();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!launched) context.showFailure(failureMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    employee.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          if (employee.hasMobile) ...<Widget>[
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Call'),
              subtitle: Text(employee.displayMobile),
              onTap: () => _contact(
                context,
                () => ContactLauncher.call(employee.mobile!),
                'Could not open the dialer.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => _contact(
                context,
                () => ContactLauncher.whatsApp(employee.mobile!),
                'WhatsApp is not installed.',
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit details'),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.employeeEdit(employee.id));
            },
          ),
          ListTile(
            leading: Icon(
              employee.isActive
                  ? Icons.person_off_outlined
                  : Icons.person_add_alt_outlined,
            ),
            title: Text(employee.isActive ? 'Deactivate' : 'Reactivate'),
            onTap: () => _toggleActive(context, ref),
          ),
          AppSpacing.gapSm,
        ],
      ),
    );
  }
}
