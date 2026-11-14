import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Turns a course's ClassSessionDto list into an attendance register and exports it to Excel / PDF.
/// Mirrors the web's utils/attendance.js + utils/attendanceExport.js so both apps show the same numbers.

class ClassAttendanceRow {
  final int id;
  final DateTime start;
  final DateTime end;
  final String teacherName;
  final bool marked;
  final int? durationMinutes;
  final bool? teacherPresent;
  final int totalStudents;
  final int? presentCount;
  final List<String> absentNames;
  final bool? selfPresent;

  ClassAttendanceRow({
    required this.id,
    required this.start,
    required this.end,
    required this.teacherName,
    required this.marked,
    required this.durationMinutes,
    required this.teacherPresent,
    required this.totalStudents,
    required this.presentCount,
    required this.absentNames,
    required this.selfPresent,
  });

  double get presentRatio => (presentCount == null || totalStudents == 0) ? 0 : presentCount! / totalStudents;
}

class StudentAttendanceRow {
  final int id;
  final String name;
  int total = 0;
  int attended = 0;
  StudentAttendanceRow(this.id, this.name);
  int get missed => total - attended;
  int get percent => total == 0 ? 0 : (attended * 100 / total).round();
}

class AttendanceSummary {
  final int held;
  final int marked;
  final int? attendancePercent;
  final int? teacherPercent;
  final int minutes;
  const AttendanceSummary({required this.held, required this.marked, required this.attendancePercent, required this.teacherPercent, required this.minutes});
  int get pending => held - marked;
}

class AttendanceReport {
  final List<ClassAttendanceRow> classes;
  final List<StudentAttendanceRow> students;
  final AttendanceSummary summary;
  const AttendanceReport(this.classes, this.students, this.summary);
}

/// "2026-11" style key for the month a class starts in (device-local, like the rest of the app).
String attendanceMonthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
String attendanceMonthLabel(String key) => DateFormat('MMMM yyyy').format(DateTime.parse('$key-15'));

String fmtMinutes(int? minutes) {
  if (minutes == null) return '-';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

DateTime _start(dynamic s) => DateTime.parse(s['scheduledStart']).toLocal();

/// Classes that should have attendance: already started and not cancelled, newest first.
List<dynamic> heldClasses(List<dynamic> sessions) {
  final now = DateTime.now();
  return sessions.where((s) => s['status'] != 'CANCELLED' && !_start(s).isAfter(now)).toList()
    ..sort((a, b) => _start(b).compareTo(_start(a)));
}

List<String> availableAttendanceMonths(List<dynamic> sessions) {
  final keys = heldClasses(sessions).map((s) => attendanceMonthKey(_start(s))).toSet().toList()..sort();
  return keys.reversed.toList();
}

AttendanceReport buildAttendanceReport(List<dynamic> sessions, {String month = 'all', int? onlyStudentId}) {
  final held = heldClasses(sessions).where((s) => month == 'all' || attendanceMonthKey(_start(s)) == month).toList();
  final byStudent = <int, StudentAttendanceRow>{};
  var seatTotal = 0, seatPresent = 0, teacherPresentCount = 0, minutes = 0, markedCount = 0;

  final classes = held.map((s) {
    final students = List<Map<String, dynamic>>.from(s['students'] ?? []);
    final presentIds = List<Map<String, dynamic>>.from(s['attendance'] ?? [])
        .where((a) => a['present'] == true)
        .map((a) => (a['studentId'] as num).toInt())
        .toSet();
    final marked = s['durationMinutes'] != null;
    if (marked) {
      markedCount++;
      seatTotal += students.length;
      seatPresent += students.where((st) => presentIds.contains((st['id'] as num).toInt())).length;
      if (s['teacherPresent'] == true) teacherPresentCount++;
      minutes += (s['durationMinutes'] as num).toInt();
      for (final st in students) {
        final id = (st['id'] as num).toInt();
        if (onlyStudentId != null && id != onlyStudentId) continue;
        final row = byStudent.putIfAbsent(id, () => StudentAttendanceRow(id, st['name'] ?? ''));
        row.total++;
        if (presentIds.contains(id)) row.attended++;
      }
    }
    return ClassAttendanceRow(
      id: (s['id'] as num).toInt(),
      start: _start(s),
      end: DateTime.parse(s['scheduledEnd']).toLocal(),
      teacherName: s['teacherName'] ?? '',
      marked: marked,
      durationMinutes: marked ? (s['durationMinutes'] as num).toInt() : null,
      teacherPresent: s['teacherPresent'] as bool?,
      totalStudents: students.length,
      presentCount: marked ? students.where((st) => presentIds.contains((st['id'] as num).toInt())).length : null,
      absentNames: marked ? students.where((st) => !presentIds.contains((st['id'] as num).toInt())).map((st) => st['name'] as String? ?? '').toList() : [],
      selfPresent: marked && onlyStudentId != null ? presentIds.contains(onlyStudentId) : null,
    );
  }).toList();

  final students = byStudent.values.toList()
    ..sort((a, b) {
      final c = a.percent.compareTo(b.percent);
      return c != 0 ? c : a.name.compareTo(b.name);
    });

  final self = onlyStudentId != null && students.isNotEmpty ? students.first : null;
  return AttendanceReport(
    classes,
    students,
    AttendanceSummary(
      held: held.length,
      marked: markedCount,
      attendancePercent: self?.percent ?? (seatTotal == 0 ? null : (seatPresent * 100 / seatTotal).round()),
      teacherPercent: markedCount == 0 ? null : (teacherPresentCount * 100 / markedCount).round(),
      minutes: minutes,
    ),
  );
}

// ---------------------------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------------------------

String _safeName(String s) {
  final out = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return out.isEmpty ? 'attendance' : out;
}

final _dateFmt = DateFormat('EEE, d MMM yyyy');
final _timeFmt = DateFormat('h:mm a');

List<String> _classHeaders(bool studentView) => [
      'Date', 'Time', 'Teacher', 'Duration', 'Teacher present',
      if (studentView) 'You' else ...['Students present', 'Absent'],
    ];

List<String> _classCells(ClassAttendanceRow c, bool studentView) => [
      _dateFmt.format(c.start),
      '${_timeFmt.format(c.start)} - ${_timeFmt.format(c.end)}',
      c.teacherName,
      c.marked ? fmtMinutes(c.durationMinutes) : '-',
      c.marked ? (c.teacherPresent == true ? 'Present' : 'Absent') : '-',
      if (studentView)
        c.marked ? (c.selfPresent == true ? 'Present' : 'Absent') : 'Not marked'
      else ...[
        c.marked ? '${c.presentCount}/${c.totalStudents}' : 'Not marked',
        c.absentNames.join(', '),
      ],
    ];

List<List<String>> _summaryRows(AttendanceReport r, bool studentView) {
  final s = r.summary;
  return [
    ['Classes held', '${s.held}'],
    ['Attendance marked', '${s.marked}'],
    ['Not marked yet', '${s.pending}'],
    [studentView ? 'Your attendance' : 'Average student attendance', s.attendancePercent == null ? '-' : '${s.attendancePercent}%'],
    ['Teacher attendance', s.teacherPercent == null ? '-' : '${s.teacherPercent}%'],
    ['Time taught', fmtMinutes(s.minutes)],
  ];
}

Future<void> exportAttendanceExcel({
  required String courseTitle,
  required String periodLabel,
  required AttendanceReport report,
  required bool studentView,
}) async {
  final book = xl.Excel.createExcel();
  final header = xl.CellStyle(
    bold: true,
    fontColorHex: xl.ExcelColor.white,
    backgroundColorHex: xl.ExcelColor.fromHexString('#1A4C8B'),
  );
  final boldStyle = xl.CellStyle(bold: true);

  void styleRow(xl.Sheet sheet, int rowIndex, int cols, xl.CellStyle style) {
    for (var c = 0; c < cols; c++) {
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex)).cellStyle = style;
    }
  }

  final defaultSheet = book.getDefaultSheet() ?? 'Sheet1';
  book.rename(defaultSheet, 'Summary');
  final sum = book['Summary'];
  sum.appendRow([xl.TextCellValue('$courseTitle - Attendance')]);
  styleRow(sum, 0, 1, xl.CellStyle(bold: true, fontSize: 14, fontColorHex: xl.ExcelColor.fromHexString('#1A4C8B')));
  sum.appendRow([xl.TextCellValue('Period: $periodLabel')]);
  sum.appendRow([xl.TextCellValue('Generated: ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}')]);
  sum.appendRow([]);
  for (final r in _summaryRows(report, studentView)) {
    sum.appendRow([xl.TextCellValue(r[0]), xl.TextCellValue(r[1])]);
    styleRow(sum, sum.maxRows - 1, 1, boldStyle);
  }
  sum.setColumnWidth(0, 30);
  sum.setColumnWidth(1, 20);

  final cls = book['Classes'];
  final headers = _classHeaders(studentView);
  cls.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());
  styleRow(cls, 0, headers.length, header);
  for (final c in report.classes) {
    cls.appendRow(_classCells(c, studentView).map((v) => xl.TextCellValue(v)).toList());
  }
  const widths = [22.0, 20.0, 22.0, 12.0, 15.0, 16.0, 40.0];
  for (var i = 0; i < headers.length; i++) {
    cls.setColumnWidth(i, widths[i]);
  }

  final st = book[studentView ? 'My attendance' : 'Students'];
  const stHeaders = ['Student', 'Classes marked', 'Attended', 'Missed', 'Attendance %'];
  st.appendRow(stHeaders.map((h) => xl.TextCellValue(h)).toList());
  styleRow(st, 0, stHeaders.length, header);
  for (final r in report.students) {
    st.appendRow([xl.TextCellValue(r.name), xl.IntCellValue(r.total), xl.IntCellValue(r.attended), xl.IntCellValue(r.missed), xl.TextCellValue('${r.percent}%')]);
  }
  st.setColumnWidth(0, 28);
  for (var i = 1; i < stHeaders.length; i++) {
    st.setColumnWidth(i, 15);
  }

  final bytes = book.save();
  if (bytes == null) throw Exception('Could not build the Excel file');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_safeName(courseTitle)}-attendance-${_safeName(periodLabel)}.xlsx');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
    subject: '$courseTitle attendance ($periodLabel)',
  ));
}

Future<void> exportAttendancePdf({
  required String courseTitle,
  required String periodLabel,
  required AttendanceReport report,
  required bool studentView,
}) async {
  const navy = PdfColor.fromInt(0xFF1A4C8B);
  const orange = PdfColor.fromInt(0xFFF2941D);
  const muted = PdfColor.fromInt(0xFF66707F);
  const border = PdfColor.fromInt(0xFFE2E6EE);
  const zebra = PdfColor.fromInt(0xFFF5F7FB);
  const ok = PdfColor.fromInt(0xFF1C8A4B);
  const warn = PdfColor.fromInt(0xFFB8720A);
  const bad = PdfColor.fromInt(0xFFC62828);

  PdfColor toneFor(String v) {
    if (v == 'Present') return ok;
    if (v == 'Absent') return bad;
    if (v == 'Not marked') return warn;
    return PdfColors.black;
  }

  pw.Widget table(List<String> headers, List<List<String>> rows, {PdfColor Function(int col, String v)? color}) {
    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.6),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: navy),
          children: [
            for (final h in headers)
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isOdd ? zebra : PdfColors.white),
            children: [
              for (var c = 0; c < rows[i].length; c++)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(rows[i][c], style: pw.TextStyle(fontSize: 9, color: color?.call(c, rows[i][c]) ?? PdfColors.black)),
                ),
            ],
          ),
      ],
    );
  }

  final doc = pw.Document(title: '$courseTitle attendance', creator: 'StepUp Hub');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            padding: const pw.EdgeInsets.all(14),
            decoration: const pw.BoxDecoration(color: navy, border: pw.Border(bottom: pw.BorderSide(color: orange, width: 3))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('$courseTitle - Attendance', style: pw.TextStyle(color: PdfColors.white, fontSize: 17, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text('Period: $periodLabel', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                ]),
                pw.Text('Generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ],
            ),
          )
        : pw.SizedBox(),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text('StepUp Hub - Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: muted)),
    ),
    build: (ctx) => [
      pw.Row(children: [
        for (final r in _summaryRows(report, studentView))
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: zebra, border: pw.Border.all(color: border), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(r[1], style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: navy)),
                pw.SizedBox(height: 2),
                pw.Text(r[0].toUpperCase(), style: const pw.TextStyle(fontSize: 7.5, color: muted)),
              ]),
            ),
          ),
      ]),
      pw.SizedBox(height: 18),
      pw.Text('Class-wise register', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: navy)),
      pw.SizedBox(height: 6),
      table(_classHeaders(studentView), report.classes.map((c) => _classCells(c, studentView)).toList(), color: (_, v) => toneFor(v)),
      if (report.students.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        pw.Text(studentView ? 'Your attendance' : 'Student-wise summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: navy)),
        pw.SizedBox(height: 6),
        table(
          const ['Student', 'Classes marked', 'Attended', 'Missed', 'Attendance %'],
          report.students.map((r) => [r.name, '${r.total}', '${r.attended}', '${r.missed}', '${r.percent}%']).toList(),
          color: (col, v) {
            if (col != 4) return PdfColors.black;
            final p = int.tryParse(v.replaceAll('%', '')) ?? 0;
            return p >= 75 ? ok : (p >= 50 ? warn : bad);
          },
        ),
      ],
    ],
  ));

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: '${_safeName(courseTitle)}-attendance-${_safeName(periodLabel)}.pdf',
  );
}
