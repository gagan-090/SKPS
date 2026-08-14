import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_status.dart';
import 'report_controller.dart';

/// Builds the monthly attendance PDF: A4 landscape, one bordered matrix,
/// totals on the right, generated-on stamp and page numbers in the footer.
class PdfBuilder {
  const PdfBuilder._();

  static const PdfColor _ink = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
  static const PdfColor _headerFill = PdfColor.fromInt(0xFFE3EFE9);
  static const PdfColor _brand = PdfColor.fromInt(0xFF1B4D3E);

  static PdfColor _statusColor(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => const PdfColor.fromInt(0xFF16A34A),
    AttendanceStatus.absent => const PdfColor.fromInt(0xFFDC2626),
    AttendanceStatus.halfDay => const PdfColor.fromInt(0xFFB45309),
    AttendanceStatus.leave => const PdfColor.fromInt(0xFF4F46E5),
  };

  static Future<Uint8List> build(
    ReportData data, {
    required String businessName,
  }) async {
    final document = pw.Document(
      title: 'Attendance ${data.monthLabel}',
      author: businessName,
    );

    final generatedOn = AppDate.displayLong(DateTime.now());
    final generatedAt = AppDate.time(DateTime.now());

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 20),
        header: (pw.Context context) => context.pageNumber == 1
            ? _titleBlock(data, businessName)
            : _runningHeader(data, businessName),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'Generated on $generatedOn at $generatedAt',
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
            ],
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          _matrix(data),
          pw.SizedBox(height: 10),
          _legend(),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _titleBlock(ReportData data, String businessName) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                businessName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _brand,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Attendance Report',
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                data.monthLabel,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${data.rows.length} '
                '${data.rows.length == 1 ? 'employee' : 'employees'} · '
                '${data.daysMarked} days marked',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _runningHeader(ReportData data, String businessName) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        '$businessName · Attendance · ${data.monthLabel}',
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
    );
  }

  static pw.Widget _matrix(ReportData data) {
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(96),
      for (int day = 1; day <= data.daysInMonth; day++)
        day: const pw.FlexColumnWidth(),
      for (int i = 0; i < 4; i++)
        data.daysInMonth + 1 + i: const pw.FixedColumnWidth(26),
      data.daysInMonth + 5: const pw.FixedColumnWidth(30),
    };

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.4),
      columnWidths: columnWidths,
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerFill),
          // Repeat the day numbers at the top of every page.
          repeat: true,
          children: <pw.Widget>[
            _headerCell('Employee', align: pw.Alignment.centerLeft),
            for (int day = 1; day <= data.daysInMonth; day++)
              _headerCell('$day'),
            _headerCell('P'),
            _headerCell('A'),
            _headerCell('H'),
            _headerCell('L'),
            _headerCell('Days'),
          ],
        ),
        for (final ReportRow row in data.rows)
          pw.TableRow(
            children: <pw.Widget>[
              _nameCell(row),
              for (int day = 1; day <= data.daysInMonth; day++)
                _dayCell(data, row, day),
              _totalCell('${row.totals.present}'),
              _totalCell('${row.totals.absent}'),
              _totalCell('${row.totals.halfDay}'),
              _totalCell('${row.totals.leave}'),
              _totalCell('${row.totals.totalMarked}', bold: true),
            ],
          ),
      ],
    );
  }

  static pw.Widget _headerCell(
    String text, {
    pw.Alignment align = pw.Alignment.center,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _nameCell(ReportRow row) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            row.employee.name,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          if (row.employee.hasMobile)
            pw.Text(
              row.employee.mobile!,
              style: const pw.TextStyle(fontSize: 6, color: _muted),
            ),
        ],
      ),
    );
  }

  static pw.Widget _dayCell(ReportData data, ReportRow row, int day) {
    final record = row.byDay[day];
    if (record == null) {
      final before = row.isBeforeJoining(data.year, data.month, day);
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(
          before ? '-' : '',
          style: const pw.TextStyle(fontSize: 6.5, color: _muted),
        ),
      );
    }

    final color = _statusColor(record.status);
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      color: PdfColor(color.red, color.green, color.blue, 0.14),
      child: pw.Text(
        record.status.shortCode,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _totalCell(String text, {bool bold = false}) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _legend() {
    return pw.Row(
      children: <pw.Widget>[
        for (final AttendanceStatus status in AttendanceStatus.values)
          pw.Container(
            margin: const pw.EdgeInsets.only(right: 12),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: <pw.Widget>[
                pw.Container(width: 8, height: 8, color: _statusColor(status)),
                pw.SizedBox(width: 4),
                pw.Text(
                  '${status.shortCode} = ${status.label}',
                  style: const pw.TextStyle(fontSize: 7, color: _muted),
                ),
              ],
            ),
          ),
        pw.Text(
          '-  = before joining',
          style: const pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ],
    );
  }

  /// `Attendance_August_2026.pdf`
  static String fileName(ReportData data, {String? employeeName}) {
    final month = AppDate.monthYear(data.year, data.month).replaceAll(' ', '_');
    final who = employeeName == null
        ? ''
        : '_${employeeName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';
    return 'Attendance_$month$who.pdf';
  }
}
