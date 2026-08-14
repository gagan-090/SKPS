import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/local/offline_store.dart';
import '../../data/models/employee.dart';
import '../../data/repositories/employee_repository.dart';

/// The roster. Loaded once and kept in memory; every mutation updates the
/// cached list so the UI never has to re-fetch just to show its own change.
class EmployeeListController extends AsyncNotifier<List<Employee>> {
  EmployeeRepository get _repository => ref.read(employeeRepositoryProvider);

  OfflineStore get _store => ref.read(offlineStoreProvider);

  @override
  Future<List<Employee>> build() => _load();

  /// Fetches the roster, mirroring it to local storage. If the phone is
  /// offline, the last known roster is used so attendance can still be marked.
  Future<List<Employee>> _load() async {
    try {
      final employees = await _repository.fetchAll();
      await _store.cacheRoster(employees);
      return employees;
    } on AppException catch (error) {
      if (!error.isNetwork) rethrow;
      final cached = _store.cachedRoster();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<Employee> create(Employee draft) async {
    final created = await _repository.create(draft);
    _replaceAll(<Employee>[...(state.value ?? <Employee>[]), created]);
    return created;
  }

  /// Named `updateEmployee` rather than `update`, which `AsyncNotifier`
  /// already defines for state transformations.
  Future<Employee> updateEmployee(Employee employee) async {
    final saved = await _repository.update(employee);
    _replaceOne(saved);
    return saved;
  }

  Future<Employee> setActive(String id, {required bool isActive}) async {
    final saved = await _repository.setActive(id, isActive: isActive);
    _replaceOne(saved);
    return saved;
  }

  Future<void> hardDelete(String id) async {
    await _repository.hardDelete(id);
    final current = state.value ?? <Employee>[];
    _replaceAll(current.where((Employee e) => e.id != id).toList());
  }

  void _replaceOne(Employee employee) {
    final current = state.value ?? <Employee>[];
    _replaceAll(<Employee>[
      for (final Employee e in current)
        if (e.id == employee.id) employee else e,
    ]);
  }

  void _replaceAll(List<Employee> employees) {
    final sorted = <Employee>[...employees]
      ..sort((Employee a, Employee b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    state = AsyncValue<List<Employee>>.data(sorted);
  }
}

final AsyncNotifierProvider<EmployeeListController, List<Employee>>
employeeListProvider =
    AsyncNotifierProvider<EmployeeListController, List<Employee>>(
      EmployeeListController.new,
    );

/// Active employees only, in roster order.
final Provider<List<Employee>> activeEmployeesProvider =
    Provider<List<Employee>>((Ref ref) {
      final all = ref.watch(employeeListProvider).value ?? <Employee>[];
      return all.where((Employee e) => e.isActive).toList();
    });

/// A single employee out of the cached roster, or null while it loads.
final employeeByIdProvider = Provider.family<Employee?, String>((
  Ref ref,
  String id,
) {
  final all = ref.watch(employeeListProvider).value ?? <Employee>[];
  for (final Employee employee in all) {
    if (employee.id == id) return employee;
  }
  return null;
});

/// Filter applied on the Employees tab.
enum EmployeeFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const EmployeeFilter(this.label);

  final String label;

  bool matches(Employee employee) => switch (this) {
    EmployeeFilter.all => true,
    EmployeeFilter.active => employee.isActive,
    EmployeeFilter.inactive => !employee.isActive,
  };
}

/// Name / mobile search. Client-side is plenty at this scale.
List<Employee> filterEmployees(
  List<Employee> employees, {
  required String query,
  required EmployeeFilter filter,
}) {
  final needle = query.trim().toLowerCase();
  return employees.where((Employee employee) {
    if (!filter.matches(employee)) return false;
    if (needle.isEmpty) return true;
    return employee.name.toLowerCase().contains(needle) ||
        (employee.mobile ?? '').contains(needle);
  }).toList();
}
