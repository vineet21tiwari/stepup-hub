import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  List<dynamic> _courses = [];
  List<dynamic> _teacherApps = [];
  List<dynamic> _bookingApprovals = [];
  List<dynamic> _sessions = [];
  List<dynamic> _students = [];
  List<dynamic> _teachers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      CourseApi.list(),
      TeacherApi.pendingApplications(),
      EnrollmentApi.pendingForAdmin(),
      SessionApi.mine(),
      UserApi.byRole('STUDENT'),
      UserApi.byRole('TEACHER'),
    ]);
    if (!mounted) return;
    setState(() {
      _courses = results[0];
      _teacherApps = results[1];
      _bookingApprovals = results[2];
      _sessions = results[3];
      _students = results[4];
      _teachers = results[5];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = (context.watch<AuthState>().user?['name'] as String? ?? '').split(' ').first;
    if (_loading) return const LoadingView();
    final scheduled = _sessions.where((s) => s['status'] == 'SCHEDULED').length;
    // A weekly booking spans many dated occurrences under one batchId — count it as one request.
    final pendingBookingCount = groupEnrollmentRequests(_bookingApprovals).length;
    final shown = pickRecentOrUpcoming(_sessions);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Platform overview.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              StatCard('${_courses.length}', 'Active courses'),
              StatCard('${_students.length}', 'Students'),
              StatCard('${_teachers.length}', 'Teachers'),
              StatCard('$scheduled', 'Scheduled classes'),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              title: const Text('Teacher applications awaiting review'),
              trailing: Text('${_teacherApps.length} pending', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Bookings awaiting final approval'),
              trailing: Text('$pendingBookingCount pending', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SectionHeader(shown.isUpcoming ? 'Upcoming classes' : 'Recent classes'),
          if (shown.items.isEmpty) const EmptyState('No classes scheduled yet.'),
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
