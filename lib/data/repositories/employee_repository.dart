import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../models/employee.dart';

/// The only place `employees` rows are read or written.
class EmployeeRepository {
  const EmployeeRepository();

  static const String _table = 'employees';

  SupabaseClient get _client => Supabase.instance.client;

  String get _ownerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException(
        'Your session has expired. Please log in again.',
      );
    }
    return id;
  }

  /// All employees for the owner, active first, then alphabetical.
  Future<List<Employee>> fetchAll({bool activeOnly = false}) async {
    try {
      final query = _client.from(_table).select();
      final rows = activeOnly
          ? await query.eq('is_active', true).order('name')
          : await query.order('is_active', ascending: false).order('name');
      return rows
          .map((Map<String, dynamic> row) => Employee.fromMap(row))
          .toList();
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<Employee> fetchById(String id) async {
    try {
      final row = await _client.from(_table).select().eq('id', id).single();
      return Employee.fromMap(row);
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<Employee> create(Employee employee) async {
    try {
      final payload = <String, dynamic>{
        ...employee.toMap(),
        'owner_id': _ownerId,
      };
      final row = await _client.from(_table).insert(payload).select().single();
      return Employee.fromMap(row);
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<Employee> update(Employee employee) async {
    try {
      final row = await _client
          .from(_table)
          .update(employee.toMap())
          .eq('id', employee.id)
          .select()
          .single();
      return Employee.fromMap(row);
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  /// Soft delete. Attendance history is preserved.
  Future<Employee> setActive(String id, {required bool isActive}) async {
    try {
      final row = await _client
          .from(_table)
          .update(<String, dynamic>{'is_active': isActive})
          .eq('id', id)
          .select()
          .single();
      return Employee.fromMap(row);
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  /// Permanent removal. Cascades to every attendance row for this employee.
  Future<void> hardDelete(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  /// Employees who could have been marked on [day]: active, and already joined.
  static List<Employee> rosterFor(List<Employee> all, DateTime day) {
    final target = AppDate.dateOnly(day);
    return all
        .where((Employee e) => e.isActive && e.wasEmployedOn(target))
        .toList();
  }
}

final Provider<EmployeeRepository> employeeRepositoryProvider =
    Provider<EmployeeRepository>((Ref ref) => const EmployeeRepository());
