import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../utils/attendance_report.dart';
import '../widgets/common.dart';

/// Course attendance: headline stats, class-wise register and per-student summary, filterable by
/// month, exportable to Excel / PDF via the share sheet. Mirrors the web's AttendanceReport.jsx.
/// A student only sees their own attendance in the summary (and a "You" status per class).
class AttendanceReportScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  const AttendanceReportScreen({super.key, required this.courseId, required this.courseTitle});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

const _okColor = Color(0xFF1C8A4B);
const _warnColor = Color(0xFFB8720A);
const _badColor = Color(0xFFC62828);

Color _toneColor(int? p) {
  if (p == null) return kNavy;
  if (p >= 75) return _okColor;
  if (p >= 50) return _warnColor;
  return _badColor;
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  List<dynamic>? _sessions;
  String? _error;
  String _month = 'all';
  bool _studentWise = false;
  String? _exporting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await SessionApi.forCourse(widget.courseId);
      if (mounted) setState(() { _sessions = s; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  bool get _studentView => context.read<AuthState>().isStudent;

  AttendanceReport _report() {
    final auth = context.read<AuthState>();
    final selfId = auth.isStudent ? (auth.user?['id'] as num?)?.toInt() : null;
    return buildAttendanceReport(_sessions!, month: _month, onlyStudentId: selfId);
  }

  String get _periodLabel => _month == 'all' ? 'All time' : attendanceMonthLabel(_month);

  Future<void> _export(String kind) async {
    setState(() => _exporting = kind);
    try {
      final report = _report();
      if (kind == 'excel') {
        await exportAttendanceExcel(courseTitle: widget.courseTitle, periodLabel: _periodLabel, report: report, studentView: _studentView);
      } else {
        await exportAttendancePdf(courseTitle: widget.courseTitle, periodLabel: _periodLabel, report: report, studentView: _studentView);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _sessions == null ? null : _report();
    final canExport = report != null && report.summary.held > 0 && _exporting == null;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Attendance'),
          Text(widget.courseTitle, style: const TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          if (_exporting != null)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            PopupMenuButton<String>(
              enabled: canExport,
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share),
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'excel', child: ListTile(leading: Icon(Icons.table_chart, color: Color(0xFF1D7A45)), title: Text('Export to Excel'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf, color: _badColor), title: Text('Export to PDF'), contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
      ),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(16), child: InfoBanner.error(_error!))
          : report == null
              ? const LoadingView()
              : RefreshIndicator(onRefresh: _load, child: _body(report)),
    );
  }

  Widget _body(AttendanceReport report) {
    final months = availableAttendanceMonths(_sessions!);
    final s = report.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _monthChip('all', 'All time'),
              for (final m in months) _monthChip(m, attendanceMonthLabel(m)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (s.held == 0)
          EmptyState(_month == 'all' ? 'No classes have taken place yet.' : 'No classes in $_periodLabel.', icon: Icons.event_available)
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: [
              _statTile(s.attendancePercent == null ? '-' : '${s.attendancePercent}%', _studentView ? 'Your attendance' : 'Avg. attendance', percent: s.attendancePercent),
              _statTile('${s.marked}/${s.held}', 'Classes marked'),
              _statTile(s.teacherPercent == null ? '-' : '${s.teacherPercent}%', 'Teacher present', percent: s.teacherPercent),
              _statTile(fmtMinutes(s.minutes), 'Time taught'),
            ],
          ),
          const SizedBox(height: 12),
          if (s.pending > 0)
            InfoBanner.warn('${s.pending} past class${s.pending == 1 ? '' : 'es'} still ${s.pending == 1 ? 'has' : 'have'} no attendance recorded.'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text('Class-wise (${report.classes.length})')),
                ButtonSegment(value: true, label: Text(_studentView ? 'My summary' : 'Student-wise (${report.students.length})')),
              ],
              selected: {_studentWise},
              onSelectionChanged: (v) => setState(() => _studentWise = v.first),
            ),
          ),
          const SizedBox(height: 12),
          if (!_studentWise)
            for (final c in report.classes) _classCard(c)
          else if (report.students.isEmpty)
            const EmptyState('No marked classes yet.', icon: Icons.fact_check_outlined)
          else
            for (final st in report.students) _studentCard(st),
        ],
      ],
    );
  }

  Widget _monthChip(String key, String label) {
    final selected = _month == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: kNavy,
        labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w700, fontSize: 12.5),
        onSelected: (_) => setState(() => _month = key),
      ),
    );
  }

  BoxDecoration _cardDecoration({Color? tint}) => BoxDecoration(
        color: tint ?? Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadiusSm),
        border: Border.all(color: Theme.of(context).dividerColor),
      );

  Widget _bar(double ratio, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: ratio.clamp(0, 1), minHeight: 6, color: color, backgroundColor: Colors.grey.withValues(alpha: 0.18)),
      );

  Widget _statTile(String value, String label, {int? percent}) {
    final color = percent == null ? kNavy : _toneColor(percent);
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(
          width: 4,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kNavy, kOrange])),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color))),
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.4)),
              if (percent != null) ...[const SizedBox(height: 6), _bar(percent / 100, color)],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
      );

  Widget _classCard(ClassAttendanceRow c) {
    final timeFmt = DateFormat('h:mm a');
    final pct = (c.presentRatio * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(tint: c.marked ? null : kOrange.withValues(alpha: 0.08)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(DateFormat('MMM').format(c.start).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNavy)),
              Text('${c.start.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNavy, height: 1.1)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('EEEE').format(c.start)} · ${timeFmt.format(c.start)} - ${timeFmt.format(c.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              Text(c.teacherName, style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
            ]),
          ),
          if (!c.marked)
            _pill('Not marked', _warnColor)
          else if (_studentView)
            _pill(c.selfPresent == true ? 'Present' : 'Absent', c.selfPresent == true ? _okColor : _badColor),
        ]),
        if (c.marked) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _meta(Icons.timer_outlined, fmtMinutes(c.durationMinutes)),
            _meta(Icons.school_outlined, 'Teacher ${c.teacherPresent == true ? 'present' : 'absent'}', color: c.teacherPresent == true ? _okColor : _badColor),
          ]),
          if (!_studentView) ...[
            const SizedBox(height: 10),
            Row(children: [
              Text('${c.presentCount}/${c.totalStudents} present', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(width: 10),
              Expanded(child: _bar(c.presentRatio, _toneColor(pct))),
            ]),
            if (c.absentNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Absent: ${c.absentNames.join(', ')}', style: const TextStyle(color: _badColor, fontSize: 12.5)),
            ],
          ],
        ],
      ]),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _studentCard(StudentAttendanceRow s) {
    final color = _toneColor(s.percent);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(children: [
        UserAvatar(s.name, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              _pill('${s.percent}%', color),
            ]),
            const SizedBox(height: 6),
            _bar(s.percent / 100, color),
            const SizedBox(height: 4),
            Text('Attended ${s.attended} of ${s.total} · Missed ${s.missed}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
