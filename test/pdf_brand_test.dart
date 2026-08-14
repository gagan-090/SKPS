import 'package:flutter_test/flutter_test.dart';
import 'package:skps_attendance/data/models/attendance_record.dart';
import 'package:skps_attendance/data/models/attendance_status.dart';
import 'package:skps_attendance/data/models/day_summary.dart';
import 'package:skps_attendance/data/models/employee.dart';
import 'package:skps_attendance/features/reports/pdf_builder.dart';
import 'package:skps_attendance/features/reports/report_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('report PDF embeds the SKPS mark', () async {
    final employee = Employee(
      id: 'e1',
      name: 'Ramesh Kumar',
      mobile: '9876543210',
      isActive: true,
      joinedOn: DateTime(2026, 1, 1),
    );
    final data = ReportData(
      year: 2026,
      month: 8,
      daysInMonth: 31,
      rows: <ReportRow>[
        ReportRow(
          employee: employee,
          byDay: <int, AttendanceRecord>{
            1: AttendanceRecord(
              employeeId: 'e1',
              day: DateTime(2026, 8, 1),
              status: AttendanceStatus.present,
            ),
          },
          totals: const EmployeeMonthTotals(
            employeeId: 'e1',
            present: 1,
            absent: 0,
            halfDay: 0,
            leave: 0,
          ),
        ),
      ],
    );

    final bytes = await PdfBuilder.build(data, businessName: 'SKPS');

    // The header logo and the watermark share one embedded bitmap, so a single
    // image XObject is all the evidence the mark made it into the document.
    final text = String.fromCharCodes(bytes.where((int b) => b < 128));
    expect(text.contains('/Image'), isTrue, reason: 'no image XObject');
  });
}
