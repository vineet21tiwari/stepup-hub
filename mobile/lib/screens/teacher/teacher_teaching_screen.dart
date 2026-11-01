import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';
import 'teacher_slots_screen.dart';

class TeacherTeachingScreen extends StatelessWidget {
  const TeacherTeachingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [Tab(text: 'Courses'), Tab(text: 'My Slots')],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_CoursesTab(), TeacherSlotsTab()]),
          ),
        ],
      ),
    );
  }
}

class _CoursesTab extends StatefulWidget {
  const _CoursesTab();

  @override
  State<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<_CoursesTab> {
  List<dynamic> _courses = [];
  List<dynamic> _applications = [];
  bool _loading = true;
  int? _applying;
  int? _uploadingVideoFor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([CourseApi.list(), TeacherApi.myApplications()]);
    if (!mounted) return;
    setState(() {
      _courses = results[0];
      _applications = results[1];
      _loading = false;
    });
  }

  Map<String, dynamic>? _appFor(int courseId) {
    for (final a in _applications) {
      if (a['courseId'] == courseId) return a;
    }
    return null;
  }

  Future<XFile?> _pickVideo() {
    return showModalBottomSheet<XFile?>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Record a new intro video'),
            onTap: () async => Navigator.pop(c, await ImagePicker().pickVideo(source: ImageSource.camera)),
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Choose from gallery'),
            onTap: () async => Navigator.pop(c, await ImagePicker().pickVideo(source: ImageSource.gallery)),
          ),
        ]),
      ),
    );
  }

  /// Apply to teach, optionally attaching a short intro video students see when picking a teacher.
  Future<void> _apply(Map<String, dynamic> course) async {
    XFile? video;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text('Apply to teach ${course['title']}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Intro video (optional) — a short clip students can watch when picking a teacher for this course.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final v = await _pickVideo();
                if (v != null) setDialog(() => video = v);
              },
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: Text(video == null ? 'Add intro video' : 'Video selected — tap to change'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (go != true) return;
    final courseId = course['id'] as int;
    setState(() {
      _applying = courseId;
      _error = null;
    });
    try {
      await TeacherApi.apply(courseId, videoPath: video?.path);
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _applying = null);
    }
  }

  Future<void> _withdraw(Map<String, dynamic> app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Withdraw this application?'),
        content: const Text('You can re-apply later if you change your mind.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _error = null);
    try {
      await TeacherApi.cancelApplication(app['id']);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _addVideo(Map<String, dynamic> app) async {
    final picked = await _pickVideo();
    if (picked == null) return;
    setState(() => _uploadingVideoFor = app['id']);
    try {
      await TeacherApi.addApplicationVideo(app['id'], picked.path);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploadingVideoFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) InfoBanner.error(_error!),
          if (_courses.isEmpty) const EmptyState('No courses have been created yet.'),
          ..._courses.map((c) {
            final app = _appFor(c['id']);
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          if ((c['subject'] ?? '').toString().isNotEmpty) Text(c['subject'], style: const TextStyle(color: Colors.grey)),
                          if ((c['description'] ?? '').toString().isNotEmpty) Text(c['description'], style: const TextStyle(fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      app != null
                          ? StatusPill(app['status'])
                          : ElevatedButton(
                              onPressed: _applying == c['id'] ? null : () => _apply(c),
                              child: Text(_applying == c['id'] ? 'Applying...' : 'Apply'),
                            ),
                    ]),
                    Wrap(spacing: 4, children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c['id']))),
                        child: const Text('View course page'),
                      ),
                      if (app != null)
                        TextButton.icon(
                          onPressed: _uploadingVideoFor == app['id'] ? null : () => _addVideo(app),
                          icon: const Icon(Icons.videocam_outlined, size: 16),
                          label: Text(_uploadingVideoFor == app['id']
                              ? 'Uploading...'
                              : (app['introVideoUrl'] != null ? 'Replace intro video' : 'Add intro video')),
                        ),
                      if (app != null && app['introVideoUrl'] != null)
                        TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse(fileUrl(app['introVideoUrl'])), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.play_circle_outline, size: 16),
                          label: const Text('Watch'),
                        ),
                      if (app != null && app['status'] == 'PENDING')
                        TextButton(onPressed: () => _withdraw(app), child: const Text('Withdraw')),
                    ]),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
