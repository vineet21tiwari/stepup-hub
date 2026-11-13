import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/endpoints.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const _jsDayToJava = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
const _dayLabel = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

/// Weekly recurring availability (several time ranges per day, copy to other days) or a single
/// one-off slot, plus the teacher's posted slots grouped by series. Booked slots are locked — the
/// teacher can edit/remove only empty ones. Mirrors TeacherSlots.jsx.
class TeacherSlotsTab extends StatefulWidget {
  const TeacherSlotsTab({super.key});

  @override
  State<TeacherSlotsTab> createState() => _TeacherSlotsTabState();
}

class _TeacherSlotsTabState extends State<TeacherSlotsTab> {
  List<dynamic> _approvedCourses = [];
  List<dynamic> _slots = [];
  bool _loading = true;
  String _mode = 'weekly';
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([TeacherApi.myApplications(), TeacherApi.mySlots()]);
    if (!mounted) return;
    setState(() {
      _approvedCourses = results[0].where((a) => a['status'] == 'APPROVED').toList();
      _slots = results[1];
      _loading = false;
    });
  }

  void _snack(Object msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
  }

  Future<bool> _confirm(String title, [String? body]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removeSlot(Map<String, dynamic> s) async {
    if (!await _confirm('Remove this slot?', fmtRange(s['startTime'], s['endTime']))) return;
    try {
      await TeacherApi.cancelSlot(s['id']);
      await _load();
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _removeEmptyInSeries(String groupId) async {
    if (!await _confirm('Remove empty slots?', 'Every EMPTY slot in this series will be removed. Slots booked or requested by students stay — only admin can cancel those.')) return;
    try {
      final res = await TeacherApi.cancelSlotSeries(groupId);
      final kept = res['keptBooked'] ?? 0;
      _snack('Removed ${res['cancelled']} empty slot(s).${kept > 0 ? ' $kept booked slot(s) kept.' : ''}');
      await _load();
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _editSlot(Map<String, dynamic> s) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSlotSheet(slot: s),
    );
    if (saved == true) {
      _snack('Slot updated. Students with a pending request were notified.');
      await _load();
    }
  }

  List<_SlotGroup> _groups() {
    final map = <String, _SlotGroup>{};
    for (final s in _slots) {
      final gid = s['recurrenceGroupId'] as String?;
      final key = gid ?? 'single-${s['id']}';
      map.putIfAbsent(key, () => _SlotGroup(key, gid)).slots.add(Map<String, dynamic>.from(s));
    }
    final list = map.values.toList();
    for (final g in list) {
      g.slots.sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
    }
    list.sort((a, b) => (a.slots.first['startTime'] as String).compareTo(b.slots.first['startTime'] as String));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final groups = _groups();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_approvedCourses.isEmpty)
            const EmptyState("You don't have any approved courses yet. Apply to a course and wait for Admin approval.")
          else ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly'), icon: Icon(Icons.event_repeat, size: 18)),
                ButtonSegment(value: 'single', label: Text('Single slot'), icon: Icon(Icons.event, size: 18)),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 14),
            if (_mode == 'weekly')
              _WeeklyForm(approvedCourses: _approvedCourses, onCreated: _load)
            else
              _SingleForm(approvedCourses: _approvedCourses, onCreated: _load),
          ],
          const SizedBox(height: 24),
          const SectionHeader('Your schedule'),
          _ScheduleView(slots: _slots.where((s) => s['cancelled'] != true).toList()),
          const SizedBox(height: 16),
          const SectionHeader('Manage slots'),
          const Text('Booked slots are locked. To move a booked class, open it and raise a change request; only admin can cancel booked slots.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          if (groups.isEmpty) const EmptyState('No slots posted yet.'),
          for (final g in groups) _groupCard(g),
        ],
      ),
    );
  }

  Widget _groupCard(_SlotGroup g) {
    final first = g.slots.first;
    final booked = g.slots.where((s) => (s['bookedCount'] ?? 0) > 0).length;
    final open = !g.isSeries || _expanded.contains(g.key);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(first['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            CountPill(g.isSeries ? 'Weekly series' : 'One-off'),
            CountPill(first['sessionType'] == 'GROUP' ? 'Group' : '1-on-1'),
            CountPill('${g.slots.length} slot${g.slots.length == 1 ? '' : 's'} · $booked booked'),
          ]),
          if (g.isSeries) ...[
            const SizedBox(height: 6),
            Text('${fmtDate(first['startTime'])} → ${fmtDate(g.slots.last['startTime'])}',
                style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => open ? _expanded.remove(g.key) : _expanded.add(g.key)),
                icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
                label: Text(open ? 'Hide slots' : 'View slots'),
              ),
              OutlinedButton.icon(
                onPressed: () => _removeEmptyInSeries(g.groupId!),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Color(0xFFC62828)),
                label: const Text('Remove empty', style: TextStyle(color: Color(0xFFC62828))),
              ),
            ]),
          ],
          if (open) ...[
            const SizedBox(height: 8),
            for (final s in g.slots) _slotRow(s),
          ],
        ]),
      ),
    );
  }

  Widget _slotRow(Map<String, dynamic> s) {
    final locked = (s['bookedCount'] ?? 0) > 0;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFF1C8A4B).withValues(alpha: 0.10) : cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmtRange(s['startTime'], s['endTime']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${s['bookedCount']}/${s['capacity']} booked', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        if (locked)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 16, color: Color(0xFF1C8A4B)),
              SizedBox(width: 4),
              Text('Booked', style: TextStyle(color: Color(0xFF1C8A4B), fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          )
        else ...[
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editSlot(s)),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFC62828)),
            onPressed: () => _removeSlot(s),
          ),
        ],
      ]),
    );
  }
}

class _SlotGroup {
  final String key;
  final String? groupId;
  final List<Map<String, dynamic>> slots = [];
  _SlotGroup(this.key, this.groupId);
  bool get isSeries => groupId != null;
}

class _Range {
  TimeOfDay? start;
  TimeOfDay? end;
  _Range([this.start, this.end]);
  _Range copy() => _Range(start, end);
  bool get complete => start != null && end != null;
}

int _mins(TimeOfDay t) => t.hour * 60 + t.minute;
String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _WeeklyForm extends StatefulWidget {
  final List<dynamic> approvedCourses;
  final VoidCallback onCreated;
  const _WeeklyForm({required this.approvedCourses, required this.onCreated});

  @override
  State<_WeeklyForm> createState() => _WeeklyFormState();
}

class _WeeklyFormState extends State<_WeeklyForm> {
  int? _courseId;
  String _sessionType = 'ONE_ON_ONE';
  final _classesPerWeek = TextEditingController(text: '1');
  final _capacity = TextEditingController(text: '1');
  final List<int> _weekdays = []; // 0=Sun..6=Sat
  final Map<int, List<_Range>> _ranges = {};
  String _startDate = _todayIso();
  String? _endDate;
  bool _busy = false;
  String? _error;
  String? _result;

  void _toggleDay(int d) {
    setState(() {
      if (_weekdays.contains(d)) {
        _weekdays.remove(d);
        _ranges.remove(d);
      } else {
        _weekdays.add(d);
        _weekdays.sort();
        _ranges[d] = [_Range()];
      }
      final perWeek = int.tryParse(_classesPerWeek.text) ?? 1;
      if (_weekdays.isNotEmpty && perWeek > _weekdays.length) _classesPerWeek.text = '${_weekdays.length}';
    });
  }

  Future<void> _pickTime(int day, int idx, bool isStart) async {
    final r = _ranges[day]![idx];
    final t = await showTimePicker(context: context, initialTime: (isStart ? r.start : r.end) ?? (isStart ? const TimeOfDay(hour: 9, minute: 0) : (r.start == null ? const TimeOfDay(hour: 10, minute: 0) : TimeOfDay(hour: (r.start!.hour + 1) % 24, minute: r.start!.minute))));
    if (t == null) return;
    setState(() => isStart ? r.start = t : r.end = t);
  }

  void _copyTo(int day, List<int> targets) {
    setState(() {
      for (final t in targets) {
        if (t != day) _ranges[t] = _ranges[day]!.map((r) => r.copy()).toList();
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    final iso = d.toIso8601String().substring(0, 10);
    setState(() => isStart ? _startDate = iso : _endDate = iso);
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _result = null;
    });
    if (_courseId == null || _weekdays.isEmpty) return setState(() => _error = 'Pick a course and at least one day of the week.');
    for (final d in _weekdays) {
      final ranges = _ranges[d] ?? [];
      if (ranges.isEmpty || ranges.any((r) => !r.complete)) {
        return setState(() => _error = 'Set a start and end time for every slot on ${_dayLabel[d]}.');
      }
      if (ranges.any((r) => _mins(r.end!) <= _mins(r.start!))) {
        return setState(() => _error = 'End time must be after start time on ${_dayLabel[d]}.');
      }
      final sorted = ranges.toList()..sort((a, b) => _mins(a.start!) - _mins(b.start!));
      for (var i = 1; i < sorted.length; i++) {
        if (_mins(sorted[i].start!) < _mins(sorted[i - 1].end!)) {
          return setState(() => _error = 'Time slots overlap on ${_dayLabel[d]}.');
        }
      }
    }
    if (_endDate == null) return setState(() => _error = 'Pick a repeat-until date.');
    if (_endDate!.compareTo(_startDate) < 0) return setState(() => _error = 'Repeat-until date must be on or after the start date.');
    final classesPerWeek = int.tryParse(_classesPerWeek.text) ?? 0;
    if (classesPerWeek < 1 || classesPerWeek > _weekdays.length) {
      return setState(() => _error = 'Classes per week must be between 1 and ${_weekdays.length} (the number of days you offered).');
    }

    setState(() => _busy = true);
    try {
      final created = await TeacherApi.createRecurringSlots({
        'courseId': _courseId,
        'sessionType': _sessionType,
        'capacity': _sessionType == 'ONE_ON_ONE' ? 1 : (int.tryParse(_capacity.text) ?? 1),
        'classesPerWeek': classesPerWeek,
        'startDate': _startDate,
        'repeatUntil': _endDate,
        'dayWindows': [
          for (final d in _weekdays)
            for (final r in _ranges[d]!) {'dayOfWeek': _jsDayToJava[d], 'startTime': _hhmm(r.start!), 'endTime': _hhmm(r.end!)},
        ],
      });
      setState(() => _result = 'Created ${created.length} slot${created.length == 1 ? '' : 's'}.');
      widget.onCreated();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) InfoBanner.error(_error!),
          if (_result != null) InfoBanner.info(_result!),
          DropdownButtonFormField<int>(
            initialValue: _courseId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Course'),
            items: widget.approvedCourses
                .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(value: a['courseId'] as int, child: Text(a['courseTitle'], overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _courseId = v),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'ONE_ON_ONE', label: Text('1-on-1')),
              ButtonSegment(value: 'GROUP', label: Text('Group')),
            ],
            selected: {_sessionType},
            onSelectionChanged: (v) => setState(() => _sessionType = v.first),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _classesPerWeek,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Classes/week needed'),
                keyboardType: TextInputType.number,
              ),
            ),
            if (_sessionType == 'GROUP') ...[
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _capacity, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number)),
            ],
          ]),
          const SizedBox(height: 14),
          const Text('Which days are you free?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(7, (d) {
              return FilterChip(
                label: Text(_dayLabel[d]),
                selected: _weekdays.contains(d),
                showCheckmark: false,
                selectedColor: kNavy,
                labelStyle: TextStyle(color: _weekdays.contains(d) ? Colors.white : null, fontWeight: FontWeight.w700),
                onSelected: (_) => _toggleDay(d),
              );
            }),
          ),
          for (final d in _weekdays) ...[const SizedBox(height: 10), _dayCard(d)],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateTile('Repeat from', _startDate, () => _pickDate(true))),
            const SizedBox(width: 10),
            Expanded(child: _dateTile('Repeat until', _endDate ?? 'Pick date', () => _pickDate(false))),
          ]),
          const SizedBox(height: 10),
          Text(
            'Each time range is split into 1-hour slots on every matching day. Students will pick '
            '${_classesPerWeek.text.isEmpty ? 'N' : _classesPerWeek.text} of your offered day${_weekdays.length == 1 ? '' : 's'} per week. '
            "Once a student books a slot, you can't change or remove it.",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating slots...' : 'Create weekly availability')),
        ],
      ),
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusSm),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(value, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }

  Widget _dayCard(int d) {
    final ranges = _ranges[d]!;
    final idx = _weekdays.indexOf(d);
    final prevDay = idx > 0 ? _weekdays[idx - 1] : null;
    final prevOk = prevDay != null && (_ranges[prevDay] ?? []).every((r) => r.complete);
    final thisOk = ranges.every((r) => r.complete);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(kRadiusSm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(_dayLabel[d], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Copy times',
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            onSelected: (v) {
              if (v == 'prev' && prevDay != null) _copyTo(prevDay, [d]);
              if (v == 'all') _copyTo(d, _weekdays);
            },
            itemBuilder: (_) => [
              if (prevDay != null)
                PopupMenuItem(value: 'prev', enabled: prevOk, child: Text('Same as ${_dayLabel[prevDay]}')),
              PopupMenuItem(value: 'all', enabled: thisOk && _weekdays.length > 1, child: Text('Copy ${_dayLabel[d]} to all days')),
            ],
          ),
        ]),
        for (var i = 0; i < ranges.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: _timeButton(ranges[i].start, 'From', () => _pickTime(d, i, true))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('to', style: TextStyle(color: Colors.grey))),
              Expanded(child: _timeButton(ranges[i].end, 'To', () => _pickTime(d, i, false))),
              SizedBox(
                width: 40,
                child: ranges.length > 1
                    ? IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFC62828), size: 20),
                        onPressed: () => setState(() => ranges.removeAt(i)),
                      )
                    : null,
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => ranges.add(_Range())),
            icon: const Icon(Icons.add_circle, size: 20),
            label: const Text('Add another time slot'),
          ),
        ),
      ]),
    );
  }

  Widget _timeButton(TimeOfDay? t, String hint, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8)),
      onPressed: onTap,
      child: Text(t == null ? hint : t.format(context), style: TextStyle(fontSize: 13.5, color: t == null ? Colors.grey : null)),
    );
  }
}

class _SingleForm extends StatefulWidget {
  final List<dynamic> approvedCourses;
  final VoidCallback onCreated;
  const _SingleForm({required this.approvedCourses, required this.onCreated});

  @override
  State<_SingleForm> createState() => _SingleFormState();
}

class _SingleFormState extends State<_SingleForm> {
  int? _courseId;
  DateTime? _start;
  DateTime? _end;
  final _capacity = TextEditingController(text: '1');
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_courseId == null || _start == null || _end == null) return setState(() => _error = 'Please fill in course, start and end time');
    if (!_end!.isAfter(_start!)) return setState(() => _error = 'End time must be after start time');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TeacherApi.createSlot({
        'courseId': _courseId,
        'startTime': _start!.toUtc().toIso8601String(),
        'endTime': _end!.toUtc().toIso8601String(),
        'capacity': int.tryParse(_capacity.text) ?? 1,
      });
      setState(() {
        _start = null;
        _end = null;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot added')));
      widget.onCreated();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) InfoBanner.error(_error!),
          DropdownButtonFormField<int>(
            initialValue: _courseId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Course'),
            items: widget.approvedCourses
                .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(value: a['courseId'] as int, child: Text(a['courseTitle'], overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _courseId = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: _capacity, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _DateTimeField(label: 'Start time', value: _start, onPicked: (v) => setState(() => _start = v)),
          const SizedBox(height: 10),
          _DateTimeField(label: 'End time', value: _end, initial: _start, onPicked: (v) => setState(() => _end = v)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving...' : 'Add slot')),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateTime? initial;
  final ValueChanged<DateTime> onPicked;
  const _DateTimeField({required this.label, required this.value, required this.onPicked, this.initial});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusSm),
      onTap: () async {
        final now = DateTime.now();
        final init = value ?? initial ?? now;
        final date = await showDatePicker(context: context, initialDate: init.isBefore(now) ? now : init, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init));
        if (time == null) return;
        onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(value == null ? 'Pick date & time' : fmtDateTime(value!.toUtc().toIso8601String())),
      ),
    );
  }
}

/// Edit one empty slot's time (and capacity).
class _EditSlotSheet extends StatefulWidget {
  final Map<String, dynamic> slot;
  const _EditSlotSheet({required this.slot});

  @override
  State<_EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends State<_EditSlotSheet> {
  late DateTime _start = DateTime.parse(widget.slot['startTime']).toLocal();
  late DateTime _end = DateTime.parse(widget.slot['endTime']).toLocal();
  late final _capacity = TextEditingController(text: '${widget.slot['capacity'] ?? 1}');
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (!_end.isAfter(_start)) return setState(() => _error = 'End time must be after start time');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TeacherApi.updateSlot(widget.slot['id'], {
        'courseId': widget.slot['courseId'],
        'startTime': _start.toUtc().toIso8601String(),
        'endTime': _end.toUtc().toIso8601String(),
        'capacity': int.tryParse(_capacity.text) ?? 1,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Edit slot · ${widget.slot['courseTitle']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 14),
        if (_error != null) InfoBanner.error(_error!),
        _DateTimeField(label: 'Start', value: _start, onPicked: (v) => setState(() {
              final dur = _end.difference(_start);
              _start = v;
              _end = v.add(dur.isNegative ? const Duration(hours: 1) : dur);
            })),
        const SizedBox(height: 10),
        _DateTimeField(label: 'End', value: _end, onPicked: (v) => setState(() => _end = v)),
        const SizedBox(height: 10),
        TextField(controller: _capacity, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save slot')),
      ]),
    );
  }
}

/// One day at a time of the teacher's posted slots, with prev/next day — opens on the earliest
/// upcoming slot. Mirrors the web's DayCalendar on the My Slots page.
class _ScheduleView extends StatefulWidget {
  final List<dynamic> slots;
  const _ScheduleView({required this.slots});

  @override
  State<_ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<_ScheduleView> {
  DateTime? _day;

  DateTime _initialDay() {
    final now = DateTime.now();
    final upcoming = widget.slots.map((s) => DateTime.parse(s['startTime']).toLocal()).where((d) => d.isAfter(now)).toList()..sort();
    final d = upcoming.isNotEmpty ? upcoming.first : now;
    return DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) return const EmptyState('No slots posted yet.');
    final day = _day ?? _initialDay();
    final items = widget.slots.where((s) => sameDay(DateTime.parse(s['startTime']).toLocal(), day)).toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _day = day.subtract(const Duration(days: 1)))),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _day = picked);
              },
              child: Text(DateFormat('EEEE, MMM d').format(day), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _day = day.add(const Duration(days: 1)))),
        ]),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No slots this day', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ),
        for (final s in items)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: s['full'] == true ? 0.04 : 0.08),
              borderRadius: BorderRadius.circular(kRadiusSm),
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(
                '${fmtTimeRange(s['startTime'], s['endTime'])} · ${s['bookedCount']}/${s['capacity']}${s['recurrenceGroupId'] != null ? ' · Series' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ]),
          ),
      ],
    );
  }
}
