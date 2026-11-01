import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

/// Post a global announcement for everyone, or a course-scoped one for its teachers, students and
/// coordinators; edit or delete any of them. Mirrors AdminAnnouncements.jsx.
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<dynamic> _items = [];
  List<dynamic> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    CourseApi.list().then((c) {
      if (mounted) setState(() => _courses = c);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    try {
      final a = await AnnouncementApi.all();
      a.sort((x, y) => (y['createdAt'] ?? '').compareTo(x['createdAt'] ?? ''));
      if (mounted) {
        setState(() {
          _items = a;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _AnnouncementSheet(existing: existing, courses: _courses, onSaved: _load),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(title: const Text("Delete this announcement? This can't be undone."), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ]),
    );
    if (ok != true) return;
    try {
      await AnnouncementApi.delete(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('New announcement')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            if (_error != null) InfoBanner.error(_error!),
            if (_items.isEmpty) const EmptyState('No announcements posted yet.'),
            ..._items.map((a) => Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                CountPill(a['scope'] == 'COURSE' ? (a['courseTitle'] ?? 'Course') : 'Global'),
                              ]),
                              const SizedBox(height: 4),
                              Text(a['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text('${a['createdByName'] ?? ''} · ${fmtDateTime(a['createdAt'])}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) => v == 'edit' ? _openForm(a) : _delete(a['id']),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
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

class _AnnouncementSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> courses;
  final Future<void> Function() onSaved;
  const _AnnouncementSheet({this.existing, required this.courses, required this.onSaved});

  @override
  State<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends State<_AnnouncementSheet> {
  late final _title = TextEditingController(text: widget.existing?['title'] ?? '');
  late final _message = TextEditingController(text: widget.existing?['message'] ?? '');
  late String _scope = widget.existing?['scope'] ?? 'GLOBAL';
  late int? _courseId = widget.existing?['courseId'] as int?;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'Title and message are required.');
      return;
    }
    if (_scope == 'COURSE' && _courseId == null) {
      setState(() => _error = 'Choose a course for a course-scoped announcement.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = {
      'title': _title.text.trim(),
      'message': _message.text.trim(),
      'scope': _scope,
      if (_scope == 'COURSE') 'courseId': _courseId,
    };
    try {
      if (_editing) {
        await AnnouncementApi.update(widget.existing!['id'], payload);
      } else {
        await AnnouncementApi.create(payload);
      }
      await widget.onSaved();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_editing ? 'Edit announcement' : 'New announcement', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (_error != null) InfoBanner.error(_error!),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Scope'),
              items: const [
                DropdownMenuItem(value: 'GLOBAL', child: Text('Global (everyone)')),
                DropdownMenuItem(value: 'COURSE', child: Text('Specific course')),
              ],
              onChanged: _editing ? null : (v) => setState(() => _scope = v ?? 'GLOBAL'),
            ),
            if (_scope == 'COURSE' && _editing) ...[
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Course', enabled: false),
                child: Text(widget.existing!['courseTitle'] ?? ''),
              ),
            ] else if (_scope == 'COURSE') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _courseId,
                decoration: const InputDecoration(labelText: 'Course'),
                items: widget.courses
                    .map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['title'] ?? '')))
                    .toList(),
                onChanged: (v) => setState(() => _courseId = v),
              ),
            ],
            if (_editing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("Scope and course can't be changed after posting — delete and repost if you need a different one.",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving...' : (_editing ? 'Save changes' : 'Post announcement')),
            ),
          ],
        ),
      ),
    );
  }
}
