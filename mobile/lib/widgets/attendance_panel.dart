import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'common.dart';

/// Coordinator (or admin) records how long a class actually ran and who was present, after the
/// fact. Everyone else sees the same read-only summary. Mirrors the web's AttendancePanel.jsx.
class AttendancePanelWidget extends StatefulWidget {
  final Map<String, dynamic> session;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const AttendancePanelWidget({super.key, required this.session, required this.onChanged});

  @override
  State<AttendancePanelWidget> createState() => _AttendancePanelWidgetState();
}

class _AttendancePanelWidgetState extends State<AttendancePanelWidget> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final canMark = auth.isCoordinator || auth.isAdmin;
    final s = widget.session;
    final marked = s['durationMinutes'] != null;
    final attendance = List<Map<String, dynamic>>.from(s['attendance'] ?? []);

    if (_editing) {
      return _AttendanceForm(
        session: s,
        onCancel: () => setState(() => _editing = false),
        onSaved: (updated) {
          widget.onChanged(updated);
          setState(() => _editing = false);
        },
      );
    }

    final present = attendance.where((a) => a['present'] == true).length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (marked) ...[
            Text(
              'Conducted ${s['durationMinutes']} min · $present/${(s['students'] as List? ?? attendance).length} student(s) present · Teacher: ${s['teacherPresent'] == true ? 'present' : 'absent'}',
              style: const TextStyle(color: Colors.grey, fontSize: 12.5),
            ),
            if (attendance.any((a) => a['present'] != true))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Absent: ${attendance.where((a) => a['present'] != true).map((a) => a['studentName']).join(', ')}',
                  style: const TextStyle(color: Color(0xFFC62828), fontSize: 12.5),
                ),
              ),
          ] else
            const Text('Attendance not recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
          if (canMark)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _editing = true),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                child: Text(marked ? 'Edit attendance' : 'Mark attendance'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttendanceForm extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSaved;
  const _AttendanceForm({required this.session, required this.onCancel, required this.onSaved});

  @override
  State<_AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<_AttendanceForm> {
  late DateTime _start;
  late DateTime _end;
  late bool _teacherPresent;
  late Map<int, bool> _present;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _start = DateTime.parse(s['actualStart'] ?? s['scheduledStart']).toLocal();
    _end = DateTime.parse(s['actualEnd'] ?? s['scheduledEnd']).toLocal();
    _teacherPresent = s['teacherPresent'] == null ? true : s['teacherPresent'] == true;
    final attendance = List<Map<String, dynamic>>.from(s['attendance'] ?? []);
    _present = {
      for (final st in List<Map<String, dynamic>>.from(s['students']))
        st['id'] as int: attendance.firstWhere((a) => a['studentId'] == st['id'], orElse: () => {'present': true})['present'] == true,
    };
  }

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'End time must be after start time');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await SessionApi.markAttendance(widget.session['id'], {
        'actualStart': _start.toUtc().toIso8601String(),
        'actualEnd': _end.toUtc().toIso8601String(),
        'teacherPresent': _teacherPresent,
        'studentAttendance': _present.map((k, v) => MapEntry(k.toString(), v)),
      });
      widget.onSaved(updated);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = List<Map<String, dynamic>>.from(widget.session['students']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(kRadiusSm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InfoBanner.error(_error!),
          Row(
            children: [
              Expanded(
                child: _DateTimeField(label: 'Actual start', value: _start, onTap: () => _pick(true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTimeField(label: 'Actual end', value: _end, onTap: () => _pick(false)),
              ),
            ],
          ),
          CheckboxListTile(
            value: _teacherPresent,
            onChanged: (v) => setState(() => _teacherPresent = v ?? true),
            title: Text('Teacher (${widget.session['teacherName']}) present', style: const TextStyle(fontSize: 13.5)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 2),
            child: Text('Students', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
          ...students.map((st) => CheckboxListTile(
                value: _present[st['id']] ?? true,
                onChanged: (v) => setState(() => _present[st['id']] = v ?? true),
                title: Text(st['name'], style: const TextStyle(fontSize: 13.5)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save attendance')),
              const SizedBox(width: 10),
              TextButton(onPressed: _busy ? null : widget.onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  const _DateTimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        child: Text(fmtDateTime(value.toUtc().toIso8601String()), style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }
}
