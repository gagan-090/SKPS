import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_exception.dart';
import 'csv_builder.dart';
import 'pdf_builder.dart';
import 'report_controller.dart';

/// Writes an export to a temporary file and hands it to the system share
/// sheet, so the owner can send it straight to WhatsApp or Gmail.
class ExportService {
  const ExportService();

  Future<void> shareCsv(
    ReportData data, {
    String? employeeName,
    String? businessName,
  }) async {
    try {
      final csv = CsvBuilder.build(data);
      final file = await _writeBytes(
        CsvBuilder.fileName(data, employeeName: employeeName),
        utf8.encode(csv),
      );
      await _share(
        file,
        subject: _subject(data, businessName),
        text: _message(data, businessName),
      );
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<void> sharePdf(
    ReportData data, {
    required String businessName,
    String? employeeName,
  }) async {
    try {
      final bytes = await PdfBuilder.build(data, businessName: businessName);
      final file = await _writeBytes(
        PdfBuilder.fileName(data, employeeName: employeeName),
        bytes,
      );
      await _share(
        file,
        subject: _subject(data, businessName),
        text: _message(data, businessName),
      );
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  /// Opens the OS print / save-as-PDF preview.
  Future<void> printPdf(ReportData data, {required String businessName}) async {
    try {
      await Printing.layoutPdf(
        name: PdfBuilder.fileName(data),
        onLayout: (_) => PdfBuilder.build(data, businessName: businessName),
      );
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<File> _writeBytes(String fileName, List<int> bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _share(
    File file, {
    required String subject,
    required String text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        subject: subject,
        title: subject,
        text: text,
      ),
    );
  }

  String _subject(ReportData data, String? businessName) {
    final prefix = (businessName ?? '').trim().isEmpty
        ? 'Attendance'
        : '${businessName!.trim()} attendance';
    return '$prefix — ${data.monthLabel}';
  }

  String _message(ReportData data, String? businessName) =>
      '${_subject(data, businessName)}\n'
      '${data.rows.length} employees · ${data.daysMarked} days marked.';
}

final Provider<ExportService> exportServiceProvider = Provider<ExportService>(
  (Ref ref) => const ExportService(),
);
