import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';

class CoordinatorHomeScreen extends StatefulWidget {
  const CoordinatorHomeScreen({super.key});

  @override
  State<CoordinatorHomeScreen> createState() => _CoordinatorHomeScreenState();
}

class _CoordinatorHomeScreenState extends State<CoordinatorHomeScreen> {
  List<dynamic> _sessions = [];
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthState>().userId!;
    final results = await Future.wait([SessionApi.mine(), CoordinatorApi.coursesFor(userId)]);
    if (!mounted) return;
    setState(() {
      _sessions = results[0];
      _courses = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = (context.watch<AuthState>().user?['name'] as String? ?? '').split(' ').first;
    if (_loading) return const LoadingView();
    final shown = pickRecentOrUpcoming(_sessions);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text("Classes you're coordinating.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatCard('${_courses.length}', 'Courses assigned')),
            const SizedBox(width: 10),
            Expanded(child: StatCard('${_sessions.where((s) => s['status'] == 'SCHEDULED').length}', 'Scheduled classes')),
          ]),
          const SizedBox(height: 20),
          const SectionHeader('My courses'),
          if (_courses.isEmpty) const EmptyState('No courses assigned to you yet.'),
          ..._courses.map((c) => Card(
                child: ListTile(
                  title: Text(c['title'] ?? ''),
                  subtitle: (c['subject'] ?? '').toString().isEmpty ? null : Text(c['subject']),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c['id']))),
                ),
              )),
          const SizedBox(height: 16),
          SectionHeader(shown.isUpcoming ? 'Upcoming classes' : 'Recent classes'),
          if (shown.items.isEmpty) const EmptyState('No classes assigned to you yet — an admin assigns coordinators to courses.'),
          ...shown.items.map((s) => Card(
                child: ListTile(
                  title: Text(s['courseTitle'] ?? ''),
                  subtitle: Text('${s['teacherName'] ?? ''} · ${(s['students'] as List).length} student(s)\n${fmtRange(s['scheduledStart'], s['scheduledEnd'])}'),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: s['courseId']))),
                ),
              )),
        ],
      ),
    );
  }
}
