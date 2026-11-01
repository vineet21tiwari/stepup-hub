import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  List<dynamic> _applications = [];
  List<dynamic> _pendingBookings = [];
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      TeacherApi.myApplications(),
      EnrollmentApi.pendingForTeacher(),
      SessionApi.mine(),
    ]);
    if (!mounted) return;
    setState(() {
      _applications = results[0];
      _pendingBookings = results[1];
      _sessions = results[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final name = (auth.user?['name'] as String? ?? '').split(' ').first;
    final approved = auth.user?['approved'] == true;
    if (_loading) return const LoadingView();

    final approvedCourses = _applications.where((a) => a['status'] == 'APPROVED').length;
    // A weekly booking spans many dated occurrences under one batchId — count it once.
    final pendingRequests = groupEnrollmentRequests(_pendingBookings).length;
    final scheduled = _sessions.where((s) => s['status'] == 'SCHEDULED').length;
    final shown = pickRecentOrUpcoming(_sessions);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (!approved) ...[
            const SizedBox(height: 10),
            InfoBanner.warn("Your teacher profile is pending Admin approval. You can still apply to courses, but students won't see you until you're approved."),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: StatCard('$approvedCourses', 'Courses you teach')),
            const SizedBox(width: 8),
            Expanded(child: StatCard('$pendingRequests', 'Requests to review')),
            const SizedBox(width: 8),
            Expanded(child: StatCard('$scheduled', 'Scheduled classes')),
          ]),
          const SizedBox(height: 20),
          SectionHeader(shown.isUpcoming ? 'Upcoming classes' : 'Recent classes'),
          if (shown.items.isEmpty) const EmptyState('Nothing scheduled yet.'),
          ...shown.items.map((s) => Card(
                child: ListTile(
                  title: Text(s['courseTitle'] ?? ''),
                  subtitle: Text('${(s['students'] as List).length} student(s)\n${fmtRange(s['scheduledStart'], s['scheduledEnd'])}'),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: s['courseId']))),
                ),
              )),
        ],
      ),
    );
  }
}
