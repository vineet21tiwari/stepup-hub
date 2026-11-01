import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';
import '../course_detail_screen.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await CourseApi.list();
    if (mounted) setState(() {
      _courses = c;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _CreateCourseSheet(onCreated: _load),
    );
  }

  Future<void> _deactivate(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate course?'),
        content: const Text('It will no longer be visible to students or teachers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await CourseApi.deactivate(id);
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New course'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_courses.isEmpty)
              const Text('No courses yet — tap "New course" to create the first one.', style: TextStyle(color: Colors.grey)),
            ..._courses.map((c) => Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                              if ((c['subject'] ?? '').toString().isNotEmpty) Text(c['subject'], style: const TextStyle(color: Colors.grey)),
                              if ((c['description'] ?? '').toString().isNotEmpty) Text(c['description'], style: const TextStyle(fontSize: 13)),
                              Wrap(spacing: 4, children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c['id']))),
                                  child: const Text('Open course page'),
                                ),
                                if (c['curriculumUrl'] != null)
                                  TextButton(
                                    onPressed: () => launchUrl(Uri.parse(fileUrl(c['curriculumUrl'])), mode: LaunchMode.externalApplication),
                                    child: const Text('View curriculum'),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                        IconButton(tooltip: 'Deactivate', icon: const Icon(Icons.delete_outline), onPressed: () => _deactivate(c['id'])),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CreateCourseSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateCourseSheet({required this.onCreated});

  @override
  State<_CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<_CreateCourseSheet> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _curriculumPath;
  String? _curriculumName;
  bool _busy = false;
  String? _error;

  Future<void> _pickCurriculum() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final f = res?.files.single;
    if (f?.path != null) {
      setState(() {
        _curriculumPath = f!.path;
        _curriculumName = f.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CourseApi.create({
        'title': _title.text.trim(),
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
      }, curriculumPath: _curriculumPath);
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 10),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
          const SizedBox(height: 10),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(_curriculumName ?? 'Attach curriculum PDF (optional)', style: TextStyle(color: _curriculumName == null ? Colors.grey : null)),
            onTap: _pickCurriculum,
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating...' : 'Create course')),
        ],
      ),
    );
  }
}
