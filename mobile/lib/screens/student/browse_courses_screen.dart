import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/endpoints.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';

const _activeStatuses = ['PENDING_TEACHER', 'PENDING_ADMIN', 'APPROVED'];
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Course -> teacher -> slots, with support for both a one-off single booking and a weekly-plan
/// booking (pick one day per required weekday, confirm once). No resume is shown to students here
/// (admin-only, see backend CourseTeacherDto) — only the intro video, curriculum lives on the
/// course page. Mirrors the web's BrowseCourses.jsx.
class BrowseCoursesScreen extends StatefulWidget {
  const BrowseCoursesScreen({super.key});

  @override
  State<BrowseCoursesScreen> createState() => _BrowseCoursesScreenState();
}

class _BrowseCoursesScreenState extends State<BrowseCoursesScreen> {
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    CourseApi.list().then((c) {
      if (mounted) setState(() {
        _courses = c;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_courses.isEmpty) return const EmptyState('No courses available yet.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (context, i) {
        final c = _courses[i];
        final subtitle = [
          if ((c['subject'] ?? '').toString().isNotEmpty) c['subject'],
          if ((c['description'] ?? '').toString().isNotEmpty) c['description'],
        ].join('\n');
        return Card(
          child: ListTile(
            title: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TeachersScreen(course: c))),
          ),
        );
      },
    );
  }
}

class _TeachersScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const _TeachersScreen({required this.course});

  @override
  State<_TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<_TeachersScreen> {
  List<dynamic> _teachers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    CourseApi.teachersForCourse(widget.course['id']).then((t) {
      if (mounted) setState(() {
        _teachers = t;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course['title'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: widget.course['id']))),
            child: const Text('Course page'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _teachers.isEmpty
              ? const EmptyState('No approved teachers for this course yet.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teachers.length,
                  itemBuilder: (context, i) {
                    final t = _teachers[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(t['teacherName'] ?? ''),
                              subtitle: Text(t['teacherExtraInfo'] ?? ''),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => _SlotsScreen(course: widget.course, teacher: t))),
                            ),
                            if (t['introVideoUrl'] == null)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: Text('No intro video yet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            if (t['introVideoUrl'] != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: TextButton.icon(
                                  onPressed: () => launchUrl(Uri.parse(fileUrl(t['introVideoUrl'])), mode: LaunchMode.externalApplication),
                                  icon: const Icon(Icons.play_circle_outline, size: 18),
                                  label: const Text('Watch intro video'),
                                ),
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

class _SlotsScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final Map<String, dynamic> teacher;
  const _SlotsScreen({required this.course, required this.teacher});

  @override
  State<_SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<_SlotsScreen> {
  List<dynamic> _slots = [];
  bool _loading = true;
  int? _booking;
  bool _confirming = false;
  String? _message;
  bool _messageIsError = false;
  String _typeFilter = 'ALL';
  // Days the student already has an active booking on — a single booking can't go on those days.
  Set<String> _myBookedDays = {};
  // weekday (1=Mon..7=Sun) -> selected slot, used for weekly-plan multi-day picking.
  final Map<int, Map<String, dynamic>> _selectedByWeekday = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TeacherApi.slotsForTeacherAndCourse(widget.teacher['teacherId'], widget.course['id']),
        EnrollmentApi.mine(),
      ]);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        // Only upcoming, open slots — past ones can't be booked.
        _slots = results[0]
            .where((sl) => sl['cancelled'] != true && DateTime.parse(sl['startTime']).toLocal().isAfter(now))
            .toList()
          ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
        _myBookedDays = results[1]
            .where((r) => _activeStatuses.contains(r['status']))
            .map((r) => _dayKey(DateTime.parse(r['slotStart']).toLocal()))
            .toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = e.toString();
        _messageIsError = true;
      });
    }
  }

  List<dynamic> get _visibleSlots => _typeFilter == 'ALL' ? _slots : _slots.where((s) => s['sessionType'] == _typeFilter).toList();

  int get _requiredPerWeek => _visibleSlots.isNotEmpty ? (_visibleSlots.first['classesPerWeek'] ?? 0) : 0;
  bool get _isWeeklyPlan => _requiredPerWeek > 0;

  Future<void> _book(Map<String, dynamic> slot) async {
    setState(() {
      _booking = slot['id'];
      _message = null;
    });
    try {
      await EnrollmentApi.book(slot['id']);
      setState(() {
        _message = 'Booking request sent! The teacher and admin will review it.';
        _messageIsError = false;
      });
      await _load();
    } catch (e) {
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _booking = null);
    }
  }

  Future<void> _confirmWeekly() async {
    setState(() {
      _confirming = true;
      _message = null;
    });
    try {
      final ids = _selectedByWeekday.values.map((s) => s['id'] as int).toList();
      await EnrollmentApi.bookRecurring(ids);
      setState(() {
        _message = 'Weekly booking request sent! The teacher and admin will review it.';
        _messageIsError = false;
        _selectedByWeekday.clear();
      });
      await _load();
    } catch (e) {
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group slots by local calendar day for a day-by-day picker.
    final byDay = <String, List<dynamic>>{};
    for (final s in _visibleSlots) {
      final d = DateTime.parse(s['startTime']).toLocal();
      final key = '${d.year}-${d.month}-${d.day}';
      byDay.putIfAbsent(key, () => []).add(s);
    }
    final days = byDay.keys.toList()
      ..sort((a, b) => (byDay[a]!.first['startTime'] as String).compareTo(byDay[b]!.first['startTime'] as String));

    return Scaffold(
      appBar: AppBar(title: Text(widget.teacher['teacherName'] ?? '')),
      body: _loading
          ? const LoadingView()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Wrap(
                    spacing: 6,
                    children: const {'ALL': 'All', 'ONE_ON_ONE': '1-on-1', 'GROUP': 'Group'}
                        .entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: _typeFilter == e.key,
                              onSelected: (_) => setState(() {
                                _typeFilter = e.key;
                                _selectedByWeekday.clear();
                              }),
                            ))
                        .toList(),
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _messageIsError ? InfoBanner.error(_message!) : InfoBanner.info(_message!),
                  ),
                if (_isWeeklyPlan)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InfoBanner.warn(
                        'This course needs $_requiredPerWeek class${_requiredPerWeek == 1 ? '' : 'es'} per week. Selected ${_selectedByWeekday.length}/$_requiredPerWeek day${_requiredPerWeek == 1 ? '' : 's'}.'),
                  ),
                if (_isWeeklyPlan && _selectedByWeekday.length == _requiredPerWeek)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: _confirming ? null : _confirmWeekly, child: Text(_confirming ? 'Booking...' : 'Confirm booking')),
                    ),
                  ),
                Expanded(
                  child: _visibleSlots.isEmpty
                      ? const EmptyState('No open slots for this course right now.')
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final dayKey in days) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 4),
                                child: Text(
                                  _dayHeading(byDay[dayKey]!.first['startTime']),
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, fontSize: 13),
                                ),
                              ),
                              if (!_isWeeklyPlan && _myBookedDays.contains(dayKey))
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Text('You already have a class booked this day.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: byDay[dayKey]!.map((s) => _slotChip(s)).toList(),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  String _dayHeading(String iso) {
    final d = DateTime.parse(iso).toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  Widget _slotChip(Map<String, dynamic> s) {
    final start = DateTime.parse(s['startTime']).toLocal();
    final dayBlocked = !_isWeeklyPlan && _myBookedDays.contains(_dayKey(start));
    final full = s['full'] == true || dayBlocked;
    final weekday = start.weekday;
    final isSelected = _selectedByWeekday[weekday]?['id'] == s['id'];
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusSm),
      onTap: full || _booking != null
          ? null
          : () {
              if (_isWeeklyPlan) {
                setState(() {
                  if (isSelected) {
                    _selectedByWeekday.remove(weekday);
                  } else {
                    _selectedByWeekday[weekday] = s;
                  }
                });
              } else {
                _book(s);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kOrange : (full ? Colors.grey.withValues(alpha: 0.15) : kNavy.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border(left: BorderSide(color: isSelected ? kOrangeDark : kNavy, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmtTimeRange(s['startTime'], s['endTime']),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: isSelected ? Colors.white : kNavyDark)),
            Text(
              dayBlocked ? 'Day booked' : full ? 'Full' : (_isWeeklyPlan ? (isSelected ? 'Selected' : 'Select day') : (_booking == s['id'] ? 'Booking...' : '${s['bookedCount']}/${s['capacity']} · Book')),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
