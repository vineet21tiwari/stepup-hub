import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/chat_thread.dart';
import '../../widgets/common.dart';

const _statusLabel = {'PENDING': 'Pending', 'IN_PROGRESS': 'In progress', 'DONE': 'Done'};

/// Tasks an admin assigned to this coordinator, with a deadline and a per-task file-sharing
/// thread. Mirrors CoordinatorTasks.jsx.
class CoordinatorTasksScreen extends StatefulWidget {
  const CoordinatorTasksScreen({super.key});

  @override
  State<CoordinatorTasksScreen> createState() => _CoordinatorTasksScreenState();
}

class _CoordinatorTasksScreenState extends State<CoordinatorTasksScreen> {
  List<dynamic> _tasks = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await TaskApi.mine();
    if (mounted) setState(() {
      _tasks = t;
      _loading = false;
    });
  }

  Future<void> _changeStatus(int id, String status) async {
    setState(() => _busyId = id);
    try {
      await TaskApi.updateStatus(id, status);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_tasks.isEmpty) return const EmptyState('No tasks assigned to you yet.');
    final userId = context.read<AuthState>().userId!;
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, i) {
          final t = _tasks[i];
          final overdue = t['status'] != 'DONE' && DateTime.parse(t['deadline']).toLocal().isBefore(now);
          return Card(
            child: ListTile(
              title: Row(children: [
                Expanded(child: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.w700))),
                if (t['courseTitle'] != null) ...[CountPill(t['courseTitle']), const SizedBox(width: 6)],
              ]),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From ${t['assignedByName']}'),
                  Text('Due ${fmtDateTime(t['deadline'])}${overdue ? ' · Overdue' : ''}',
                      style: TextStyle(color: overdue ? const Color(0xFFC62828) : Colors.grey, fontWeight: overdue ? FontWeight.w700 : null)),
                ],
              ),
              isThreeLine: true,
              trailing: DropdownButton<String>(
                value: t['status'],
                underline: const SizedBox.shrink(),
                items: _statusLabel.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: _busyId == t['id'] ? null : (v) => v == null ? null : _changeStatus(t['id'], v),
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
    );
  }
}
