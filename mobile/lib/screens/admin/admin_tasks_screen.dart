import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/chat_thread.dart';
import '../../widgets/common.dart';

const _statusLabel = {'PENDING': 'Pending', 'IN_PROGRESS': 'In progress', 'DONE': 'Done'};

/// Admin assigns tasks (with a deadline) to coordinators; a task can optionally be tied to a
/// course. Each task has its own file-sharing message thread. Mirrors AdminTasks.jsx.
class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _courses = [];
  List<dynamic> _coordinators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([TaskApi.mine(), CourseApi.list(), UserApi.byRole('COORDINATOR')]);
    if (!mounted) return;
    setState(() {
      _tasks = results[0];
      _courses = results[1];
      _coordinators = results[2];
      _loading = false;
    });
  }

  Future<void> _openCreate([Map<String, dynamic>? task]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _CreateTaskSheet(courses: _courses, coordinators: _coordinators, onCreated: _load, task: task),
    );
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${t['title']}" and its messages will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TaskApi.delete(t['id']);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final userId = context.read<AuthState>().userId!;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _openCreate, icon: const Icon(Icons.add), label: const Text('New task')),
      body: _tasks.isEmpty
          ? const EmptyState('No tasks assigned yet.')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _tasks.length,
                itemBuilder: (context, i) {
                  final t = _tasks[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                      title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Assigned to ${t['coordinatorName']}'),
                          Text('Due ${fmtDateTime(t['deadline'])}'),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            StatusPill(_statusLabel[t['status']] ?? t['status']),
                            if (t['courseTitle'] != null) CountPill(t['courseTitle']),
                          ]),
                        ]),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => v == 'edit' ? _openCreate(Map<String, dynamic>.from(t)) : _delete(Map<String, dynamic>.from(t)),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                              title: Text('Delete', style: TextStyle(color: Color(0xFFC62828))),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(t['title'])),
                          body: Column(children: [
                            if ((t['description'] ?? '').toString().isNotEmpty)
                              Padding(padding: const EdgeInsets.all(12), child: Text(t['description'])),
                            Expanded(
                              child: ChatThreadWidget(
                                currentUserId: userId,
                                allowAttachments: true,
                                loadHistory: () => TaskApi.messages(t['id']),
                                send: (content, path) => TaskApi.sendMessage(t['id'], content, attachmentPath: path),
                                emptyText: 'No messages on this task yet.',
                              ),
                            ),
                          ]),
                        ),
                      )),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  final List<dynamic> courses;
  final List<dynamic> coordinators;
  final VoidCallback onCreated;
  // When set, the sheet edits this task instead of creating a new one.
  final Map<String, dynamic>? task;
  const _CreateTaskSheet({required this.courses, required this.coordinators, required this.onCreated, this.task});

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  int? _courseId;
  int? _coordinatorId;
  DateTime? _deadline;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _title.text = t['title'] ?? '';
      _description.text = t['description'] ?? '';
      _courseId = t['courseId'];
      _coordinatorId = t['coordinatorId'];
      _deadline = t['deadline'] == null ? null : DateTime.parse(t['deadline']).toLocal();
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _coordinatorId == null || _deadline == null) {
      setState(() => _error = 'Title, coordinator and deadline are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = {
        'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        'courseId': _courseId,
        'coordinatorId': _coordinatorId,
        'deadline': _deadline!.toUtc().toIso8601String(),
      };
      if (widget.task != null) {
        await TaskApi.update(widget.task!['id'], payload);
      } else {
        await TaskApi.create(payload);
      }
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 0, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.task != null ? 'Edit task' : 'New task', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          if (_error != null) InfoBanner.error(_error!),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 10),
          TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _courseId,
            decoration: const InputDecoration(labelText: 'Course (optional)'),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('No specific course')),
              ...widget.courses.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'], child: Text(c['title']))),
            ],
            onChanged: (v) => setState(() => _courseId = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _coordinatorId,
            decoration: const InputDecoration(labelText: 'Coordinator'),
            items: widget.coordinators.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'], child: Text(c['name']))).toList(),
            onChanged: (v) => setState(() => _coordinatorId = v),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_deadline == null ? 'Deadline' : fmtDateTime(_deadline!.toUtc().toIso8601String())),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final now = DateTime.now();
              final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
              if (date == null || !mounted) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (time == null) return;
              setState(() => _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute));
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving...' : (widget.task != null ? 'Save changes' : 'Assign task'))),
        ],
      ),
    );
  }
}
