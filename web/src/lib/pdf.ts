import { GState, jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';

import type { ReportData, ReportRow } from '../features/report';
import { SKPS_MARK_PNG } from './brandMark';
import { AppDate } from './date';
import { STATUS, hasMobile, displayMobile, totalMarked } from '../types';

const MARK = `data:image/png;base64,${SKPS_MARK_PNG}`;

/** A faint SKPS mark centred behind the table, on every page. */
function drawWatermark(doc: jsPDF): void {
  const w = doc.internal.pageSize.getWidth();
  const h = doc.internal.pageSize.getHeight();
  const size = 320;
  doc.saveGraphicsState();
  doc.setGState(new GState({ opacity: 0.06 }));
  doc.addImage(MARK, 'PNG', (w - size) / 2, (h - size) / 2, size, size, 'skps-mark');
  doc.restoreGraphicsState();
}

/**
 * The monthly attendance PDF — landscape A4, the same shape as the printed
 * sheet the app produces, with the business name in the header.
 */
export function buildPdf(data: ReportData, businessName: string): jsPDF {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();

  doc.addImage(MARK, 'PNG', 40, 26, 34, 34, 'skps-mark');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(48, 116, 189);
  doc.text(businessName, 84, 42);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.setTextColor(110);
  doc.text(`Attendance — ${data.label}`, 84, 60);
  doc.text(
    `Generated ${AppDate.display(new Date())} at ${AppDate.time(new Date())}`,
    pageWidth - 40,
    60,
    { align: 'right' },
  );
  doc.setTextColor(0);

  const head = [
    [
      'Employee',
      ...Array.from({ length: data.daysInMonth }, (_, i) => String(i + 1)),
      'P',
      'A',
      'H',
      'L',
      'Days',
    ],
  ];

  const body = data.rows.map((row) => [
    row.employee.name +
      (hasMobile(row.employee.mobile) ? `\n${displayMobile(row.employee.mobile)}` : ''),
    ...Array.from({ length: data.daysInMonth }, (_, i) => cell(data, row, i + 1)),
    String(row.totals.present),
    String(row.totals.absent),
    String(row.totals.halfDay),
    String(row.totals.leave),
    String(totalMarked(row.totals)),
  ]);

  autoTable(doc, {
    head,
    body,
    startY: 74,
    theme: 'grid',
    styles: {
      font: 'helvetica',
      fontSize: 6.5,
      cellPadding: 2,
      halign: 'center',
      valign: 'middle',
      lineColor: [225, 228, 232],
      lineWidth: 0.5,
      overflow: 'linebreak',
    },
    headStyles: {
      fillColor: [48, 116, 189],
      textColor: 255,
      fontStyle: 'bold',
      fontSize: 6.5,
    },
    columnStyles: {
      0: { halign: 'left', cellWidth: 96, fontStyle: 'bold' },
    },
    // Tint each status cell with the same colours the app uses.
    didParseCell: (hook) => {
      if (hook.section !== 'body' || hook.column.index === 0) return;
      const text = String(hook.cell.text[0] ?? '');
      const meta = Object.values(STATUS).find((s) => s.shortCode === text);
      if (meta) {
        hook.cell.styles.textColor = hexToRgb(meta.color);
        hook.cell.styles.fontStyle = 'bold';
      }
    },
    willDrawPage: () => drawWatermark(doc),
    didDrawPage: () => {
      const pageCount = doc.getNumberOfPages();
      const page = doc.getCurrentPageInfo().pageNumber;
      doc.setFontSize(8);
      doc.setTextColor(140);
      doc.text(
        `P = Present · A = Absent · H = Half Day · L = Leave · "-" = before joining`,
        40,
        doc.internal.pageSize.getHeight() - 20,
      );
      doc.text(
        `Page ${page} of ${pageCount}`,
        pageWidth - 40,
        doc.internal.pageSize.getHeight() - 20,
        { align: 'right' },
      );
      doc.setTextColor(0);
    },
  });

  return doc;
}

function cell(data: ReportData, row: ReportRow, day: number): string {
  const record = row.byDay.get(day);
  if (record) return STATUS[record.status].shortCode;
  return row.isBeforeJoining(data.year, data.month, day) ? '-' : '';
}

function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** `Attendance_August_2026.pdf` */
export function pdfFileName(data: ReportData, employeeName?: string): string {
  const month = data.label.replace(/ /g, '_');
  const who = employeeName
    ? `_${employeeName.trim().replace(/[^A-Za-z0-9]+/g, '_').replace(/^_|_$/g, '')}`
    : '';
  return `Attendance_${month}${who}.pdf`;
}
