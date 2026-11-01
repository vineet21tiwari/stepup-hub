import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  List<dynamic> _courses = [];
  List<dynamic> _bookings = [];
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([CourseApi.list(), EnrollmentApi.mine(), SessionApi.mine()]);
    if (!mounted) return;
    setState(() {
      _courses = results[0];
      _bookings = results[1];
      _sessions = results[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = (context.watch<AuthState>().user?['name'] as String? ?? '').split(' ').first;
    if (_loading) return const LoadingView();

    // A weekly booking spans many dated occurrences under one batchId — count it once.
    final pending = groupEnrollmentRequests(_bookings.where((b) => (b['status'] as String).startsWith('PENDING')).toList()).length;
    final scheduled = _sessions.where((s) => s['status'] == 'SCHEDULED').length;
    final shown = pickRecentOrUpcoming(_sessions);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text("Here's what's happening with your studies.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatCard('${_courses.length}', 'Courses available')),
            const SizedBox(width: 8),
            Expanded(child: StatCard('$pending', 'Pending requests')),
            const SizedBox(width: 8),
            Expanded(child: StatCard('$scheduled', 'Scheduled classes')),
          ]),
          const SizedBox(height: 20),
          SectionHeader(shown.isUpcoming ? 'Upcoming classes' : 'Recent classes'),
          if (shown.items.isEmpty) const EmptyState('No classes scheduled yet — browse courses and book a slot.'),
          ...shown.items.map((s) => Card(
                child: ListTile(
                  title: Text(s['courseTitle'] ?? ''),
                  subtitle: Text('${s['teacherName'] ?? ''}\n${fmtRange(s['scheduledStart'], s['scheduledEnd'])}'),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: s['courseId']))),
                ),
              )),
        ],
      ),
    );
  }
}
