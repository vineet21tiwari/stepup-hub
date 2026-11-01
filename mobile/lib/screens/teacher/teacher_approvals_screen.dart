import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

class TeacherApprovalsScreen extends StatefulWidget {
  const TeacherApprovalsScreen({super.key});

  @override
  State<TeacherApprovalsScreen> createState() => _TeacherApprovalsScreenState();
}

class _TeacherApprovalsScreenState extends State<TeacherApprovalsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await EnrollmentApi.pendingForTeacher();
    if (mounted) setState(() {
      _requests = r;
      _loading = false;
    });
  }

  Future<void> _decide(int id, bool approve) async {
    setState(() => _busyId = id);
    try {
      await EnrollmentApi.teacherDecide(id, approve);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final groups = groupEnrollmentRequests(_requests);
    if (groups.isEmpty) return const EmptyState('No pending requests right now.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final r = g.representative;
          final busy = _busyId == r['id'];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(r['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (g.count > 1) ...[const SizedBox(width: 6), CountPill('${g.count} weekly classes')],
                  ]),
                  Text(r['courseTitle'] ?? ''),
                  Text(fmtRange(r['slotStart'], r['slotEnd']), style: const TextStyle(color: Colors.grey)),
                  Text('${r['studentEmail'] ?? ''}${(r['studentPhone'] ?? '').toString().isNotEmpty ? ' · ${r['studentPhone']}' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                  if ((r['studentExtraInfo'] ?? '').toString().isNotEmpty)
                    Text(r['studentExtraInfo'], style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(onPressed: busy ? null : () => _decide(r['id'], true), child: const Text('Approve')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: busy ? null : () => _decide(r['id'], false), child: const Text('Decline')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
