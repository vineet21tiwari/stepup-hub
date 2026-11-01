import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/endpoints.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const _jsDayToJava = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
const _dayLabel = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

/// Weekly recurring availability (with a "copy from previous day" shortcut) or a single one-off
/// slot, plus the teacher's posted schedule with cancel/cancel-series. Mirrors TeacherSlots.jsx —
/// this is the biggest gap the old mobile skeleton had (it only supported single slots).
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

  void _showError(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _cancelSlot(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(title: const Text('Cancel this slot?'), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, cancel')),
      ]),
    );
    if (ok != true) return;
    try {
      await TeacherApi.cancelSlot(id);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _cancelSeries(String groupId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(title: const Text('Cancel every remaining slot in this weekly series?'), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
      ]),
    );
    if (ok == true) {
      try {
        await TeacherApi.cancelSlotSeries(groupId);
        await _load();
      } catch (e) {
        _showError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_approvedCourses.isEmpty)
            const EmptyState("You don't have any approved courses yet. Apply to a course and wait for Admin approval.")
          else ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly availability')),
                ButtonSegment(value: 'single', label: Text('Single slot')),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 14),
            if (_mode == 'weekly')
              _WeeklyForm(approvedCourses: _approvedCourses, existingSlots: _slots, onCreated: _load)
            else
              _SingleForm(approvedCourses: _approvedCourses, existingSlots: _slots, onCreated: _load),
          ],
          const SizedBox(height: 24),
          const SectionHeader('Your schedule'),
          _ScheduleView(slots: _slots.where((s) => s['cancelled'] != true).toList()),
          const SizedBox(height: 16),
          const SectionHeader('Manage slots'),
          if (_slots.isEmpty) const EmptyState('No slots posted yet.'),
          ..._slots.map((s) => Card(
                child: ListTile(
                  title: Row(children: [
                    Flexible(child: Text(s['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (s['recurrenceGroupId'] != null) ...[const SizedBox(width: 6), const CountPill('Series')],
                    const SizedBox(width: 6),
                    CountPill(s['sessionType'] == 'GROUP' ? 'Group' : '1-on-1'),
                  ]),
                  subtitle: Text(
                      '${fmtRange(s['startTime'], s['endTime'])}\n${s['bookedCount']}/${s['capacity']} booked${s['cancelled'] == true ? ' · cancelled' : ''}${(s['classesPerWeek'] ?? 0) > 0 ? ' · ${s['classesPerWeek']} classes/week' : ''}'),
                  isThreeLine: true,
                  trailing: s['cancelled'] == true
                      ? null
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _cancelSlot(s['id'])),
                          if (s['recurrenceGroupId'] != null)
                            TextButton(
                              onPressed: () => _cancelSeries(s['recurrenceGroupId']),
                              child: const Text('Cancel series', style: TextStyle(fontSize: 10)),
                            ),
                        ]),
                ),
              )),
        ],
      ),
    );
  }
}

class _WeeklyForm extends StatefulWidget {
  final List<dynamic> approvedCourses;
  final List<dynamic> existingSlots;
  final VoidCallback onCreated;
  const _WeeklyForm({required this.approvedCourses, required this.existingSlots, required this.onCreated});

  @override
  State<_WeeklyForm> createState() => _WeeklyFormState();
}

class _WeeklyFormState extends State<_WeeklyForm> {
  int? _courseId;
  String _sessionType = 'ONE_ON_ONE';
  final _classesPerWeek = TextEditingController(text: '1');
  final _capacity = TextEditingController(text: '1');
  final List<int> _weekdays = []; // 0=Sun..6=Sat
  final Map<int, TimeOfDay> _startTimes = {};
  final Map<int, TimeOfDay> _endTimes = {};
  String _startDate = _todayIso();
  String? _endDate;
  bool _busy = false;
  String? _error;
  String? _result;

  bool get _hasActiveForCourse =>
      _courseId != null && widget.existingSlots.any((s) => s['cancelled'] != true && s['courseId'] == _courseId);

  void _toggleDay(int d) {
    setState(() {
      if (_weekdays.contains(d)) {
        _weekdays.remove(d);
        _startTimes.remove(d);
        _endTimes.remove(d);
      } else {
        _weekdays.add(d);
        _weekdays.sort();
      }
      final perWeek = int.tryParse(_classesPerWeek.text) ?? 1;
      if (_weekdays.isNotEmpty && perWeek > _weekdays.length) _classesPerWeek.text = '${_weekdays.length}';
    });
  }

  Future<void> _pickTime(int day, bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;
    setState(() => isStart ? _startTimes[day] = t : _endTimes[day] = t);
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

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _result = null;
    });
    if (_courseId == null || _weekdays.isEmpty) {
      setState(() => _error = 'Pick a course and at least one day of the week.');
      return;
    }
    for (final d in _weekdays) {
      final start = _startTimes[d];
      final end = _endTimes[d];
      if (start == null || end == null) {
        setState(() => _error = 'Set a start and end time for ${_dayLabel[d]}.');
        return;
      }
      if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
        setState(() => _error = 'End time must be after start time for ${_dayLabel[d]}.');
        return;
      }
    }
    if (_endDate == null) {
      setState(() => _error = 'Pick a repeat-until date.');
      return;
    }
    if (_endDate!.compareTo(_startDate) < 0) {
      setState(() => _error = 'Repeat-until date must be on or after the start date.');
      return;
    }
    final classesPerWeek = int.tryParse(_classesPerWeek.text) ?? 0;
    if (classesPerWeek < 1 || classesPerWeek > _weekdays.length) {
      setState(() => _error = 'Classes per week must be between 1 and ${_weekdays.length} (the number of days you offered).');
      return;
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
        'dayWindows': _weekdays
            .map((d) => {
                  'dayOfWeek': _jsDayToJava[d],
                  'startTime': _fmtTime(_startTimes[d]!),
                  'endTime': _fmtTime(_endTimes[d]!),
                })
            .toList(),
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
          DropdownButtonFormField<int>(
            initialValue: _courseId,
            decoration: const InputDecoration(labelText: 'Course'),
            items: widget.approvedCourses
                .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(value: a['courseId'] as int, child: Text(a['courseTitle'])))
                .toList(),
            onChanged: (v) => setState(() => _courseId = v),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ONE_ON_ONE', label: Text('1-on-1')),
              ButtonSegment(value: 'GROUP', label: Text('Group')),
            ],
            selected: {_sessionType},
            onSelectionChanged: (v) => setState(() => _sessionType = v.first),
          ),
          if (_hasActiveForCourse)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InfoBanner.warn('This course already has an active slot/plan. Cancel it below before creating a new one.'),
            )
          else ...[
            const SizedBox(height: 10),
            if (_error != null) InfoBanner.error(_error!),
            if (_result != null) InfoBanner.info(_result!),
            Row(children: [
              Expanded(child: TextField(controller: _classesPerWeek, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Classes/week needed'), keyboardType: TextInputType.number)),
              if (_sessionType == 'GROUP') ...[
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _capacity, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number)),
              ],
            ]),
            const SizedBox(height: 10),
            const Text('Which days are you free?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: List.generate(7, (d) {
                final selected = _weekdays.contains(d);
                return ChoiceChip(label: Text(_dayLabel[d]), selected: selected, onSelected: (_) => _toggleDay(d));
              }),
            ),
            for (final d in _weekdays) ...[
              const SizedBox(height: 8),
              _dayTimeRow(d),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat from', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  subtitle: Text(_startDate),
                  onTap: () => _pickDate(true),
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat until', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  subtitle: Text(_endDate ?? 'Pick date'),
                  onTap: () => _pickDate(false),
                ),
              ),
            ]),
            Text(
              "A slot is created for every day above, at that day's own time range. Students will pick "
              '${_classesPerWeek.text.isEmpty ? 'N' : _classesPerWeek.text} of your offered day${_weekdays.length == 1 ? '' : 's'} per week.',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating slots...' : 'Create weekly availability')),
          ],
        ],
      ),
    );
  }

  Widget _dayTimeRow(int d) {
    final prevIdx = _weekdays.indexOf(d) - 1;
    final prevDay = prevIdx >= 0 ? _weekdays[prevIdx] : null;
    final canCopy = prevDay != null && _startTimes[prevDay] != null && _endTimes[prevDay] != null;
    return Row(
      children: [
        SizedBox(width: 36, child: Text(_dayLabel[d], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickTime(d, true),
            child: Text(_startTimes[d] == null ? 'Start' : _fmtTime(_startTimes[d]!), style: const TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickTime(d, false),
            child: Text(_endTimes[d] == null ? 'End' : _fmtTime(_endTimes[d]!), style: const TextStyle(fontSize: 12)),
          ),
        ),
        if (prevDay != null)
          IconButton(
            tooltip: canCopy ? 'Copy ${_dayLabel[prevDay]}\'s time' : 'Set ${_dayLabel[prevDay]}\'s time first',
            icon: const Icon(Icons.copy, size: 16),
            onPressed: !canCopy
                ? null
                : () => setState(() {
                      _startTimes[d] = _startTimes[prevDay]!;
                      _endTimes[d] = _endTimes[prevDay]!;
                    }),
          ),
      ],
    );
  }
}

class _SingleForm extends StatefulWidget {
  final List<dynamic> approvedCourses;
  final List<dynamic> existingSlots;
  final VoidCallback onCreated;
  const _SingleForm({required this.approvedCourses, required this.existingSlots, required this.onCreated});

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

  Map<String, dynamic>? get _active =>
      widget.existingSlots.cast<Map<String, dynamic>?>().firstWhere((s) => s!['cancelled'] != true && s['courseId'] == _courseId, orElse: () => null);

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initial ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (_courseId == null || _start == null || _end == null) {
      setState(() => _error = 'Please fill in course, start and end time');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      setState(() => _error = 'End time must be after start time');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = {
        'courseId': _courseId,
        'startTime': _start!.toUtc().toIso8601String(),
        'endTime': _end!.toUtc().toIso8601String(),
        'capacity': int.tryParse(_capacity.text) ?? 1,
      };
      if (_active != null) {
        await TeacherApi.updateSlot(_active!['id'], payload);
      } else {
        await TeacherApi.createSlot(payload);
      }
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
            decoration: const InputDecoration(labelText: 'Course'),
            items: widget.approvedCourses.map<DropdownMenuItem<int>>((a) => DropdownMenuItem(value: a['courseId'] as int, child: Text(a['courseTitle']))).toList(),
            onChanged: (v) => setState(() {
              _courseId = v;
              final a = _active;
              if (a != null) {
                _start = DateTime.parse(a['startTime']).toLocal();
                _end = DateTime.parse(a['endTime']).toLocal();
                _capacity.text = '${a['capacity'] ?? 1}';
              }
            }),
          ),
          const SizedBox(height: 10),
          if (_active != null) InfoBanner.warn('You already have an active slot for this course — editing it below instead of creating a new one.'),
          TextField(controller: _capacity, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_start == null ? 'Start time' : fmtDateTime(_start!.toUtc().toIso8601String())),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final v = await _pickDateTime(_start);
              if (v != null) setState(() => _start = v);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_end == null ? 'End time' : fmtDateTime(_end!.toUtc().toIso8601String())),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final v = await _pickDateTime(_end ?? _start);
              if (v != null) setState(() => _end = v);
            },
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving...' : (_active != null ? 'Update slot' : 'Add slot'))),
        ],
      ),
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
