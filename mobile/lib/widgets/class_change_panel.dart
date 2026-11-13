import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'common.dart';

/// One reschedule/cancel request, with Approve / Decline / Withdraw when the viewer may act.
class ChangeRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onChanged;
  final bool showClass;
  const ChangeRequestCard({super.key, required this.request, this.onChanged, this.showClass = false});

  @override
  State<ChangeRequestCard> createState() => _ChangeRequestCardState();
}

class _ChangeRequestCardState extends State<ChangeRequestCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final isCancel = r['type'] == 'CANCEL';
    final approvedBy = List<String>.from(r['approvedBy'] ?? const []);
    final awaiting = List<String>.from(r['awaiting'] ?? const []);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadiusSm),
        border: Border(left: const BorderSide(color: kOrange, width: 4), top: BorderSide(color: Theme.of(context).dividerColor),
            right: BorderSide(color: Theme.of(context).dividerColor), bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            CountPill(isCancel ? 'Cancel class' : 'Reschedule'),
            StatusPill(r['status'] ?? ''),
            if (widget.showClass) Text(r['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text('Requested by ${r['requestedByName']} (${(r['requesterRole'] ?? '').toString().toLowerCase()})',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          if (widget.showClass)
            Text('Teacher ${r['teacherName']} · ${List<String>.from(r['studentNames'] ?? const []).join(', ')}',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            Text(fmtDateTime(r['originalStart']), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (!isCancel) ...[
              const Icon(Icons.arrow_forward, size: 16, color: kOrangeDark),
              Text(fmtDateTime(r['newStart']), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C8A4B))),
            ],
          ]),
          if ((r['reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('“${r['reason']}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ],
          if (r['status'] == 'PENDING') ...[
            const SizedBox(height: 4),
            Text(
              '${approvedBy.isNotEmpty ? 'Approved by ${approvedBy.join(', ')} · ' : ''}Waiting for ${awaiting.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (r['status'] == 'REJECTED' && r['rejectedByName'] != null)
            Text('Declined by ${r['rejectedByName']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (r['canDecide'] == true || r['canWithdraw'] == true) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r['canDecide'] == true) ...[
                FilledButton(
                  onPressed: _busy ? null : () => _act(() => SessionApi.decideChange(r['id'], true)),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _act(() => SessionApi.decideChange(r['id'], false)),
                  child: const Text('Decline'),
                ),
              ],
              if (r['canWithdraw'] == true)
                OutlinedButton(
                  onPressed: _busy ? null : () => _act(() => SessionApi.withdrawChange(r['id'])),
                  child: const Text('Withdraw'),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Per class: pending change requests + "Request time change / cancellation" for the class's teacher
/// or student. Changes are allowed only up to the day before the class (server sends changeAllowed).
class ClassChangePanel extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback? onApplied;
  const ClassChangePanel({super.key, required this.session, this.onApplied});

  @override
  State<ClassChangePanel> createState() => _ClassChangePanelState();
}

class _ClassChangePanelState extends State<ClassChangePanel> {
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ClassChangePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session['id'] != widget.session['id']) _load();
  }

  Future<void> _load() async {
    try {
      final r = await SessionApi.changeRequestsFor(widget.session['id']);
      if (mounted) setState(() => _requests = r);
    } catch (_) {
      // not a participant / transient — just show nothing
    }
  }

  Future<void> _openForm(String type) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChangeRequestForm(session: widget.session, type: type),
    );
    if (sent == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final s = widget.session;
    final isTeacher = s['teacherId'] == auth.userId;
    final isStudent = (s['students'] as List? ?? const []).any((st) => st['id'] == auth.userId);
    final canRaise = (isTeacher || isStudent) && s['changeAllowed'] == true;
    final pending = _requests.where((r) => r['status'] == 'PENDING').toList();
    final upcoming = s['status'] == 'SCHEDULED' && DateTime.parse(s['scheduledStart']).isAfter(DateTime.now());
    final todayLocked = (isTeacher || isStudent) && upcoming && s['changeAllowed'] != true;

    if (!canRaise && pending.isEmpty && !todayLocked) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in pending)
            ChangeRequestCard(
              request: Map<String, dynamic>.from(r),
              onChanged: () {
                _load();
                widget.onApplied?.call();
              },
            ),
          if (canRaise && pending.isEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => _openForm('RESCHEDULE'),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Change time'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openForm('CANCEL'),
                icon: const Icon(Icons.event_busy, size: 18, color: Color(0xFFC62828)),
                label: const Text('Cancel class', style: TextStyle(color: Color(0xFFC62828))),
              ),
            ]),
          if (todayLocked)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text("Classes can't be changed or cancelled on the day of the class.",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

class _ChangeRequestForm extends StatefulWidget {
  final Map<String, dynamic> session;
  final String type;
  const _ChangeRequestForm({required this.session, required this.type});

  @override
  State<_ChangeRequestForm> createState() => _ChangeRequestFormState();
}

class _ChangeRequestFormState extends State<_ChangeRequestForm> {
  DateTime? _start;
  DateTime? _end;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = DateTime.parse(widget.session['scheduledStart']).toLocal();
    final e = DateTime.parse(widget.session['scheduledEnd']).toLocal();
    _start = s;
    _end = e;
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final first = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final init = initial != null && initial.isAfter(first) ? initial : first;
    final date = await showDatePicker(context: context, initialDate: init, firstDate: first, lastDate: first.add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? init));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final reschedule = widget.type == 'RESCHEDULE';
    if (reschedule && (_start == null || _end == null || !_end!.isAfter(_start!))) {
      setState(() => _error = 'Pick a new start and an end time after it.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionApi.requestChange(widget.session['id'], {
        'type': widget.type,
        if (reschedule) 'newStart': _start!.toUtc().toIso8601String(),
        if (reschedule) 'newEnd': _end!.toUtc().toIso8601String(),
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final isTeacher = widget.session['teacherId'] == auth.userId;
    final reschedule = widget.type == 'RESCHEDULE';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(reschedule ? 'Request a new time' : 'Request cancellation',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text('${widget.session['courseTitle']} · ${fmtDateTime(widget.session['scheduledStart'])}',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          if (_error != null) InfoBanner.error(_error!),
          if (reschedule) ...[
            _pickerTile('New start', _start, () async {
              final v = await _pick(_start);
              if (v != null) {
                setState(() {
                  final dur = (_end != null && _start != null) ? _end!.difference(_start!) : const Duration(hours: 1);
                  _start = v;
                  _end = v.add(dur.isNegative || dur == Duration.zero ? const Duration(hours: 1) : dur);
                });
              }
            }),
            const SizedBox(height: 8),
            _pickerTile('New end', _end, () async {
              final v = await _pick(_end ?? _start);
              if (v != null) setState(() => _end = v);
            }),
            const SizedBox(height: 10),
          ],
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          const SizedBox(height: 8),
          Text(isTeacher ? 'The student(s) and an admin must approve.' : 'Your teacher and an admin must approve.',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending...' : (reschedule ? 'Send change request' : 'Send cancellation request')),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusSm),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(value == null ? 'Pick' : fmtDateTime(value.toUtc().toIso8601String())),
      ),
    );
  }
}
