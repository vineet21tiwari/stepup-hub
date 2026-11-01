import 'package:flutter/material.dart';
import '../api/endpoints.dart';
import '../widgets/common.dart';
import 'course_detail_screen.dart';

/// One card per course (not per class instance) — just the course and its next upcoming class.
/// Tapping opens the course page, where the full calendar of classes for that course lives.
/// Mirrors the web's Sessions.jsx. Admin sees the same simplified view too.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<_CourseGroup> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await SessionApi.mine();
    final byCourse = <int, List<dynamic>>{};
    for (final s in sessions) {
      byCourse.putIfAbsent(s['courseId'], () => []).add(s);
    }
    final now = DateTime.now();
    final groups = byCourse.entries.map((e) {
      final sorted = e.value.toList()..sort((a, b) => (a['scheduledStart'] as String).compareTo(b['scheduledStart'] as String));
      final next = sorted.firstWhere(
        (s) => DateTime.parse(s['scheduledEnd']).toLocal().isAfter(now),
        orElse: () => sorted.last,
      );
      return _CourseGroup(e.key, sorted.first['courseTitle'], sorted.first['teacherName'], next);
    }).toList()
      ..sort((a, b) => a.courseTitle.compareTo(b.courseTitle));
    if (!mounted) return;
    setState(() {
      _courses = groups;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_courses.isEmpty) return const EmptyState('No scheduled classes yet.', icon: Icons.school_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (context, i) {
          final c = _courses[i];
          return Card(
            child: ListTile(
              title: Text(c.courseTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('with ${c.teacherName}'),
              trailing: Text('Next: ${fmtTimeRange(c.next['scheduledStart'], c.next['scheduledEnd'])}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.right),
              isThreeLine: false,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c.courseId)))
                  .then((_) => _load()),
            ),
          );
        },
      ),
    );
  }
}

class _CourseGroup {
  final int courseId;
  final String courseTitle;
  final String teacherName;
  final Map<String, dynamic> next;
  _CourseGroup(this.courseId, this.courseTitle, this.teacherName, this.next);
}
