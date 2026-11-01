import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [Tab(text: 'Teacher applications'), Tab(text: 'Booking approvals')],
            ),
          ),
          const Expanded(child: TabBarView(children: [_TeacherAppsTab(), _BookingApprovalsTab()])),
        ],
      ),
    );
  }
}

class _TeacherAppsTab extends StatefulWidget {
  const _TeacherAppsTab();

  @override
  State<_TeacherAppsTab> createState() => _TeacherAppsTabState();
}

class _TeacherAppsTabState extends State<_TeacherAppsTab> {
  List<dynamic> _apps = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await TeacherApi.pendingApplications();
    if (mounted) setState(() {
      _apps = a;
      _loading = false;
    });
  }

  Future<void> _decide(int id, bool approve) async {
    setState(() => _busyId = id);
    try {
      await TeacherApi.decideApplication(id, approve);
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
    if (_apps.isEmpty) return const EmptyState('No applications pending review.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _apps.length,
        itemBuilder: (context, i) {
          final a = _apps[i];
          final busy = _busyId == a['id'];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['teacherName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if ((a['teacherExtraInfo'] ?? '').toString().isNotEmpty)
                    Text(a['teacherExtraInfo'], style: const TextStyle(color: Colors.grey)),
                  Text('Applying to teach: ${a['courseTitle'] ?? ''}'),
                  Row(children: [
                    if (a['resumeUrl'] != null)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(fileUrl(a['resumeUrl'])), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('View resume'),
                      ),
                    if (a['introVideoUrl'] != null)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(fileUrl(a['introVideoUrl'])), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text('Intro video'),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ElevatedButton(onPressed: busy ? null : () => _decide(a['id'], true), child: const Text('Approve')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: busy ? null : () => _decide(a['id'], false), child: const Text('Reject')),
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

class _BookingApprovalsTab extends StatefulWidget {
  const _BookingApprovalsTab();

  @override
  State<_BookingApprovalsTab> createState() => _BookingApprovalsTabState();
}

class _BookingApprovalsTabState extends State<_BookingApprovalsTab> {
  List<dynamic> _requests = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await EnrollmentApi.pendingForAdmin();
    if (mounted) setState(() {
      _requests = r;
      _loading = false;
    });
  }

  Future<void> _decide(int id, bool approve) async {
    setState(() => _busyId = id);
    try {
      await EnrollmentApi.adminDecide(id, approve);
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
    if (groups.isEmpty) return const EmptyState('Nothing waiting on you right now.');
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
                    Flexible(child: Text('${r['studentName']} → ${r['courseTitle']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (g.count > 1) ...[const SizedBox(width: 6), CountPill('${g.count} weekly classes')],
                  ]),
                  Text('Teacher: ${r['teacherName'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                  Text(fmtRange(r['slotStart'], r['slotEnd']), style: const TextStyle(color: Colors.grey)),
                  Text('Student: ${r['studentEmail'] ?? ''}${(r['studentPhone'] ?? '').toString().isNotEmpty ? ' · ${r['studentPhone']}' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                  if ((r['studentExtraInfo'] ?? '').toString().isNotEmpty)
                    Text(r['studentExtraInfo'], style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(onPressed: busy ? null : () => _decide(r['id'], true), child: const Text('Confirm class')),
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
