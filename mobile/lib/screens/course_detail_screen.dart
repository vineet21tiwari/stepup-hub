import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/endpoints.dart';
import '../theme.dart';
import '../widgets/attendance_panel.dart';
import '../widgets/course_chat.dart';
import '../widgets/common.dart';
import '../widgets/course_feed.dart';
import '../widgets/meeting_panel.dart';
import '../widgets/month_calendar.dart';

/// Classroom-style course page: course details (teachers, coordinators, curriculum), this user's
/// classes for the course (month calendar + day panel with meeting + attendance), and the posts /
/// announcements / assignments feed. Chat lives behind a floating action button. Mirrors the web's
/// CourseDetail.jsx (which splits chat out into a separate floating widget too).
class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Map<String, dynamic>? _course;
  List<dynamic> _teachers = [];
  List<dynamic> _coordinators = [];
  Map<String, dynamic>? _access;
  List<dynamic>? _sessions;
  DateTime _selectedDate = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        CourseApi.get(widget.courseId),
        CourseApi.teachersForCourse(widget.courseId),
        CourseApi.coordinatorsForCourse(widget.courseId),
        CourseAccessApi.get(widget.courseId),
      ]);
      if (!mounted) return;
      setState(() {
        _course = results[0] as Map<String, dynamic>;
        _teachers = results[1] as List<dynamic>;
        _coordinators = results[2] as List<dynamic>;
        _access = results[3] as Map<String, dynamic>;
      });
      if (_access!['member'] == true) await _loadSessions();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadSessions() async {
    final s = await SessionApi.forCourse(widget.courseId);
    if (!mounted) return;
    setState(() {
      _sessions = s;
      final upcoming = s
          .where((x) => DateTime.parse(x['scheduledEnd']).toLocal().isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => (a['scheduledStart'] as String).compareTo(b['scheduledStart'] as String));
      if (upcoming.isNotEmpty) _selectedDate = DateTime.parse(upcoming.first['scheduledStart']).toLocal();
    });
  }

  // Reloads sessions without moving the calendar — used when a class's join window opens.
  Future<void> _refreshSessions() async {
    try {
      final s = await SessionApi.forCourse(widget.courseId);
      if (mounted) setState(() => _sessions = s);
    } catch (_) {}
  }

  void _replaceSession(Map<String, dynamic> updated) {
    setState(() {
      _sessions = _sessions!.map((s) => s['id'] == updated['id'] ? updated : s).toList();
    });
  }

  void _openChat() => openCourseChat(context, widget.courseId, _course!['title'] ?? '');

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: Padding(padding: const EdgeInsets.all(20), child: InfoBanner.error(_error!))));
    if (_course == null || _access == null) return const Scaffold(body: LoadingView());

    final isMember = _access!['member'] == true;
    final dayClasses = (_sessions ?? [])
        .where((s) => sameDay(DateTime.parse(s['scheduledStart']).toLocal(), _selectedDate))
        .toList()
      ..sort((a, b) => (a['scheduledStart'] as String).compareTo(b['scheduledStart'] as String));

    return Scaffold(
      appBar: AppBar(title: Text(_course!['title'] ?? '')),
      floatingActionButton: isMember
          ? FloatingActionButton(onPressed: _openChat, child: const Icon(Icons.forum))
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if ((_course!['subject'] ?? '').toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_course!['subject'], style: const TextStyle(color: Colors.grey))),
            _courseInfoCard(),
            if (isMember) ...[
              const SizedBox(height: 16),
              const SectionHeader('Classes'),
              if (_sessions == null)
                const LoadingView()
              else ...[
                _nextClassBanner(),
                MonthCalendarWidget(
                  items: _sessions!,
                  selectedDate: _selectedDate,
                  onSelectDate: (d) => setState(() => _selectedDate = d),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_weekday(_selectedDate)}, ${_selectedDate.day}/${_selectedDate.month}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kNavyDark),
                ),
                const SizedBox(height: 6),
                if (dayClasses.isEmpty) const EmptyState('No classes this day.', icon: Icons.event_busy),
                for (final s in dayClasses) _dayClassCard(s),
              ],
              const SizedBox(height: 20),
              CourseFeedWidget(courseId: widget.courseId, canManage: _access!['canManage'] == true),
            ] else ...[
              const SizedBox(height: 16),
              const EmptyState('Book a class in this course to see its posts, announcements and assignments.', icon: Icons.lock_outline),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _nextClassBanner() {
    final now = DateTime.now();
    final upcoming = (_sessions ?? [])
        .where((s) => DateTime.parse(s['scheduledEnd']).toLocal().isAfter(now) && s['status'] != 'CANCELLED')
        .toList()
      ..sort((a, b) => (a['scheduledStart'] as String).compareTo(b['scheduledStart'] as String));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;
    final happeningNow = !DateTime.parse(next['scheduledStart']).toLocal().isAfter(now);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kOrange.withValues(alpha: 0.12), Theme.of(context).cardTheme.color!]),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(happeningNow ? 'HAPPENING NOW' : 'NEXT CLASS', style: const TextStyle(color: kOrangeDark, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 2),
          Text(fmtTimeRange(next['scheduledStart'], next['scheduledEnd']), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(next['teacherName'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
          const SizedBox(height: 8),
          MeetingPanelWidget(session: next, onChanged: _replaceSession, onRefresh: _refreshSessions),
        ],
      ),
    );
  }

  Widget _dayClassCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(kRadiusSm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fmtTimeRange(s['scheduledStart'], s['scheduledEnd']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(s['teacherName'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
            StatusPill(s['status'] ?? ''),
          ]),
          MeetingPanelWidget(session: s, onChanged: _replaceSession, onRefresh: _refreshSessions),
          AttendancePanelWidget(session: s, onChanged: _replaceSession),
        ],
      ),
    );
  }

  Widget _courseInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_course!['description'] ?? '').toString().isNotEmpty) Text(_course!['description']),
          if (_teachers.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 10, bottom: 4), child: Text('Teachers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            for (final t in _teachers) Text('• ${t['teacherName']}'),
          ],
          if (_coordinators.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 10, bottom: 4), child: Text('Coordinators', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            for (final c in _coordinators) Text('• ${c['name']}'),
          ],
          if (_course!['curriculumUrl'] != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(fileUrl(_course!['curriculumUrl'])), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.menu_book, size: 16),
              label: const Text('Open curriculum'),
            ),
          ],
        ],
      ),
    );
  }

  String _weekday(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
}
