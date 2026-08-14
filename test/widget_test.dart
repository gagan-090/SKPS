import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skps_attendance/core/utils/date_utils.dart';
import 'package:skps_attendance/core/utils/validators.dart';
import 'package:skps_attendance/core/widgets/employee_avatar.dart';
import 'package:skps_attendance/data/local/offline_store.dart';
import 'package:skps_attendance/data/models/attendance_record.dart';
import 'package:skps_attendance/data/models/attendance_status.dart';
import 'package:skps_attendance/data/models/employee.dart';
import 'package:skps_attendance/features/employees/employees_controller.dart';

void main() {
  group('AppDate', () {
    test('ymd uses the local calendar date, never a UTC conversion', () {
      // 00:30 IST would be the previous day in UTC. The day must not shift.
      final earlyMorning = DateTime(2026, 8, 13, 0, 30);
      expect(AppDate.ymd(earlyMorning), '2026-08-13');
    });

    test('parseYmd round-trips', () {
      expect(AppDate.ymd(AppDate.parseYmd('2026-02-09')), '2026-02-09');
    });

    test('daysInMonth handles leap years', () {
      expect(AppDate.daysInMonth(2024, 2), 29);
      expect(AppDate.daysInMonth(2026, 2), 28);
    });

    test('monthRange covers the whole month', () {
      final range = AppDate.monthRange(2026, 8);
      expect(range.first.day, 1);
      expect(range.last.day, 31);
    });
  });

  group('Validators', () {
    test('mobile is optional but validated when present', () {
      expect(Validators.mobileOptional(''), isNull);
      expect(Validators.mobileOptional('9876543210'), isNull);
      expect(Validators.mobileOptional('5876543210'), isNotNull);
      expect(Validators.mobileOptional('98765'), isNotNull);
    });

    test('employee name needs at least two characters', () {
      expect(Validators.employeeName('R'), isNotNull);
      expect(Validators.employeeName('Ramesh'), isNull);
    });
  });

  group('AttendanceStatus', () {
    test('maps to and from the Postgres enum literals', () {
      for (final status in AttendanceStatus.values) {
        expect(AttendanceStatus.fromDb(status.dbValue), status);
      }
      expect(AttendanceStatus.fromDb('half_day'), AttendanceStatus.halfDay);
    });
  });

  group('Employee', () {
    final employee = Employee(
      id: 'e1',
      name: 'Ramesh Kumar',
      isActive: true,
      joinedOn: DateTime(2026, 8, 10),
      mobile: '9876543210',
    );

    test('is not employed before the joining date', () {
      expect(employee.wasEmployedOn(DateTime(2026, 8, 9)), isFalse);
      expect(employee.wasEmployedOn(DateTime(2026, 8, 10)), isTrue);
    });

    test('formats the mobile with a country code', () {
      expect(employee.displayMobile, '+91 98765 43210');
    });

    test('serialises the joining date as YYYY-MM-DD', () {
      expect(employee.toMap()['joined_on'], '2026-08-10');
    });
  });

  group('filterEmployees', () {
    final all = <Employee>[
      Employee(
        id: '1',
        name: 'Ramesh Kumar',
        isActive: true,
        joinedOn: DateTime(2026, 1, 1),
        mobile: '9876543210',
      ),
      Employee(
        id: '2',
        name: 'Sita Devi',
        isActive: false,
        joinedOn: DateTime(2026, 1, 1),
      ),
    ];

    test('filters by status', () {
      expect(
        filterEmployees(all, query: '', filter: EmployeeFilter.active).length,
        1,
      );
      expect(
        filterEmployees(all, query: '', filter: EmployeeFilter.inactive).length,
        1,
      );
    });

    test('searches name and mobile', () {
      expect(
        filterEmployees(all, query: 'sita', filter: EmployeeFilter.all).length,
        1,
      );
      expect(
        filterEmployees(all, query: '98765', filter: EmployeeFilter.all).length,
        1,
      );
    });
  });

  group('OfflineStore', () {
    late OfflineStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = OfflineStore(await SharedPreferences.getInstance());
    });

    test('queues records and de-duplicates by employee and day', () async {
      final day = DateTime(2026, 8, 13);
      await store.enqueue(<AttendanceRecord>[
        AttendanceRecord(
          employeeId: 'e1',
          day: day,
          status: AttendanceStatus.absent,
        ),
        AttendanceRecord(
          employeeId: 'e2',
          day: day,
          status: AttendanceStatus.present,
        ),
      ]);
      expect(store.pendingCount, 2);

      // Re-marking the same person for the same day replaces, never appends.
      await store.enqueue(<AttendanceRecord>[
        AttendanceRecord(
          employeeId: 'e1',
          day: day,
          status: AttendanceStatus.present,
        ),
      ]);
      expect(store.pendingCount, 2);
      expect(
        store
            .pendingForDay('2026-08-13')
            .firstWhere((AttendanceRecord r) => r.employeeId == 'e1')
            .status,
        AttendanceStatus.present,
      );

      await store.clearPending();
      expect(store.pendingCount, 0);
    });

    test('round-trips the cached roster', () async {
      await store.cacheRoster(<Employee>[
        Employee(
          id: 'e1',
          name: 'Ramesh Kumar',
          isActive: true,
          joinedOn: DateTime(2026, 8, 1),
          mobile: '9876543210',
        ),
      ]);

      final cached = store.cachedRoster();
      expect(cached, isNotNull);
      expect(cached!.single.name, 'Ramesh Kumar');
      expect(cached.single.joinedOn, DateTime(2026, 8, 1));
    });
  });

  testWidgets('EmployeeAvatar shows initials', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmployeeAvatar(name: 'Ramesh Kumar')),
      ),
    );
    expect(find.text('RK'), findsOneWidget);
  });
}
