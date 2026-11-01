import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'common.dart';

const _typeFilters = {'ALL': 'All', 'POST': 'Posts', 'ANNOUNCEMENT': 'Announcements', 'ASSIGNMENT': 'Assignments'};

Future<bool> _confirm(BuildContext context, String title, {String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(title: Text(title), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
    ]),
  );
  return ok == true;
}

void _snack(BuildContext context, Object e) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}

Future<void> _openFile(String? path) async {
  if (path == null) return;
  await launchUrl(Uri.parse(fileUrl(path)), mode: LaunchMode.externalApplication);
}

/// The course stream: posts, announcements and assignments in one date-ordered feed, grouped by day
/// and filterable by type and by a from/to date range. Any member can post; only managers (approved
/// teacher / admin) can add announcements and assignments. Mirrors the web's CourseFeed.jsx.
class CourseFeedWidget extends StatefulWidget {
  final int courseId;
  final bool canManage;
  const CourseFeedWidget({super.key, required this.courseId, required this.canManage});

  @override
  State<CourseFeedWidget> createState() => _CourseFeedWidgetState();
}

class _CourseFeedWidgetState extends State<CourseFeedWidget> {
  List<dynamic>? _posts;
  List<dynamic>? _announcements;
  List<dynamic>? _assignments;
  String? _error;
  String _typeFilter = 'ALL';
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        PostApi.forCourse(widget.courseId),
        AnnouncementApi.forCourse(widget.courseId),
        AssignmentApi.forCourse(widget.courseId),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0];
        _announcements = results[1];
        _assignments = results[2];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _replacePost(Map<String, dynamic> updated) {
    setState(() => _posts = _posts!.map((p) => p['id'] == updated['id'] ? updated : p).toList());
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: isFrom ? DateTime(2020) : (_from ?? DateTime(2020)),
      lastDate: isFrom ? (_to ?? now.add(const Duration(days: 365))) : now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => isFrom ? _from = d : _to = d);
  }

  bool get _filtered => _typeFilter != 'ALL' || _from != null || _to != null;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final userId = auth.userId;
    final isAdmin = auth.isAdmin;

    final items = _posts == null
        ? <_FeedItem>[]
        : (<_FeedItem>[
            ..._posts!.map((p) => _FeedItem('POST', DateTime.parse(p['createdAt']).toLocal(), p)),
            ..._announcements!.map((a) => _FeedItem('ANNOUNCEMENT', DateTime.parse(a['createdAt']).toLocal(), a)),
            ..._assignments!.map((a) => _FeedItem('ASSIGNMENT', DateTime.parse(a['createdAt']).toLocal(), a)),
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

    final visible = items.where((it) {
      if (_typeFilter != 'ALL' && it.type != _typeFilter) return false;
      final day = DateTime(it.createdAt.year, it.createdAt.month, it.createdAt.day);
      if (_from != null && day.isBefore(_from!)) return false;
      if (_to != null && day.isAfter(_to!)) return false;
      return true;
    }).toList();

    // Group into calendar days, keeping the newest-first order.
    final groups = <String, List<_FeedItem>>{};
    for (final it in visible) {
      groups.putIfAbsent(DateFormat('EEEE, MMM d, yyyy').format(it.createdAt), () => []).add(it);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Composer(courseId: widget.courseId, canManage: widget.canManage, onPosted: _load),
        const SizedBox(height: 10),
        _filterBar(),
        const SizedBox(height: 10),
        if (_error != null) InfoBanner.error(_error!),
        if (_posts == null && _error == null) const Padding(padding: EdgeInsets.all(20), child: LoadingView()),
        if (_posts != null && visible.isEmpty)
          EmptyState(_filtered ? 'Nothing matches these filters.' : 'Nothing here yet — be the first to post.', icon: Icons.chat_bubble_outline),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey)),
          ),
          for (final item in entry.value) ...[
            if (item.type == 'POST')
              _PostCard(
                key: ValueKey('p${item.data['id']}'),
                post: item.data,
                canDelete: isAdmin || item.data['authorId'] == userId,
                onUpdated: _replacePost,
                onDeleted: _load,
              ),
            if (item.type == 'ANNOUNCEMENT')
              _AnnouncementCard(
                key: ValueKey('a${item.data['id']}'),
                item: item.data,
                canDelete: isAdmin || (auth.isTeacher && item.data['createdById'] == userId),
                onChanged: _load,
              ),
            if (item.type == 'ASSIGNMENT') _AssignmentCard(key: ValueKey('s${item.data['id']}'), item: item.data),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _filterBar() {
    final dateFmt = DateFormat('MMM d, yyyy');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadiusSm),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _typeFilters.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _typeFilter == e.key,
                      onSelected: (_) => setState(() => _typeFilter = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_from == null ? 'From' : 'From ${dateFmt.format(_from!)}', style: const TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_to == null ? 'To' : 'To ${dateFmt.format(_to!)}', style: const TextStyle(fontSize: 12)),
              ),
              if (_filtered)
                TextButton(
                  onPressed: () => setState(() {
                    _typeFilter = 'ALL';
                    _from = null;
                    _to = null;
                  }),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedItem {
  final String type;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  _FeedItem(this.type, this.createdAt, this.data);
}

class _Composer extends StatefulWidget {
  final int courseId;
  final bool canManage;
  final Future<void> Function() onPosted;
  const _Composer({required this.courseId, required this.canManage, required this.onPosted});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  String _mode = 'POST';
  final _postText = TextEditingController();
  final _annTitle = TextEditingController();
  final _annMessage = TextEditingController();
  final _asgTitle = TextEditingController();
  final _asgDescription = TextEditingController();
  DateTime? _asgDue;
  String? _asgFilePath;
  String? _asgFileName;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_postText, _annTitle, _annMessage, _asgTitle, _asgDescription]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      await widget.onPosted();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitAnnouncement() {
    if (_annTitle.text.trim().isEmpty || _annMessage.text.trim().isEmpty) {
      setState(() => _error = 'Title and message are required.');
      return;
    }
    _run(() async {
      await AnnouncementApi.create({
        'title': _annTitle.text.trim(),
        'message': _annMessage.text.trim(),
        'scope': 'COURSE',
        'courseId': widget.courseId,
      });
      _annTitle.clear();
      _annMessage.clear();
    });
  }

  void _submitAssignment() {
    if (_asgTitle.text.trim().isEmpty || _asgDue == null) {
      setState(() => _error = 'Title and due date are required.');
      return;
    }
    if (_asgFilePath == null || !(_asgFileName ?? '').toLowerCase().endsWith('.pdf')) {
      setState(() => _error = 'Attach the assignment as a PDF file.');
      return;
    }
    _run(() async {
      await AssignmentApi.create({
        'title': _asgTitle.text.trim(),
        if (_asgDescription.text.trim().isNotEmpty) 'description': _asgDescription.text.trim(),
        'courseId': widget.courseId,
        'dueDate': _asgDue!.toUtc().toIso8601String(),
      }, _asgFilePath!);
      _asgTitle.clear();
      _asgDescription.clear();
      setState(() {
        _asgDue = null;
        _asgFilePath = null;
        _asgFileName = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.canManage)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'POST', label: Text('Post')),
                ButtonSegment(value: 'ANNOUNCEMENT', label: Text('Announce')),
                ButtonSegment(value: 'ASSIGNMENT', label: Text('Assign')),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() {
                _mode = v.first;
                _error = null;
              }),
            ),
          if (widget.canManage) const SizedBox(height: 10),
          if (_error != null) InfoBanner.error(_error!),
          if (_mode == 'POST') ...[
            TextField(
              controller: _postText,
              maxLines: 3,
              maxLength: 2000,
              // Rebuild so the Post button enables as soon as there's text.
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Share something with this course...'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy || _postText.text.trim().isEmpty
                    ? null
                    : () => _run(() async {
                          await PostApi.create(widget.courseId, _postText.text.trim());
                          _postText.clear();
                        }),
                child: Text(_busy ? 'Posting...' : 'Post'),
              ),
            ),
          ] else if (_mode == 'ANNOUNCEMENT') ...[
            TextField(controller: _annTitle, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: _annMessage, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Message')),
            const Text('Everyone in this course is notified.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _busy ? null : _submitAnnouncement, child: Text(_busy ? 'Posting...' : 'Post announcement')),
            ),
          ] else ...[
            TextField(controller: _asgTitle, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: _asgDescription, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions (optional)')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_asgDue == null ? 'Pick due date' : 'Due ${fmtDateTime(_asgDue!.toUtc().toIso8601String())}'),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final now = DateTime.now();
                final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (time == null) return;
                setState(() => _asgDue = DateTime(date.year, date.month, date.day, time.hour, time.minute));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(_asgFileName ?? 'Attach assignment PDF', style: TextStyle(color: _asgFileName == null ? Colors.grey : null)),
              onTap: () async {
                final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
                final f = res?.files.single;
                if (f?.path != null) {
                  setState(() {
                    _asgFilePath = f!.path;
                    _asgFileName = f.name;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _busy ? null : _submitAssignment, child: Text(_busy ? 'Uploading...' : 'Post assignment')),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  const _FeedCard({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
          left: BorderSide(color: accent ?? Theme.of(context).dividerColor, width: accent == null ? 1 : 4),
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}

/// Author line shared by every feed item: kind badge, name, role pill and time.
class _FeedHead extends StatelessWidget {
  final String kind;
  final String? name;
  final String? role;
  final String? createdAt;
  const _FeedHead({required this.kind, this.name, this.role, this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CountPill(kind),
        Text(name ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        if ((role ?? '').isNotEmpty) RolePill(role!),
        Text(fmtDateTime(createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onUpdated;
  final Future<void> Function() onDeleted;
  const _PostCard({super.key, required this.post, required this.canDelete, required this.onUpdated, required this.onDeleted});

  Future<void> _like(BuildContext context) async {
    try {
      onUpdated(await PostApi.toggleLike(post['id']));
    } catch (e) {
      if (context.mounted) _snack(context, e);
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (!await _confirm(context, 'Delete this post?')) return;
    try {
      await PostApi.delete(post['id']);
      await onDeleted();
    } catch (e) {
      if (context.mounted) _snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherNames = List<String>.from(post['likerNames'] ?? []);
    final likedByMe = post['likedByMe'] == true;
    final likeCount = post['likeCount'] ?? 0;
    return _FeedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedHead(kind: 'Post', name: post['authorName'], role: post['authorRole'], createdAt: post['createdAt']),
          const SizedBox(height: 6),
          Text(post['content'] ?? ''),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => _like(context),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(likedByMe ? Icons.favorite : Icons.favorite_border, size: 16, color: likedByMe ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text('${likeCount > 0 ? '$likeCount ' : ''}${likedByMe ? 'Liked' : 'Like'}', style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
              if (likeCount > 0) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Liked by ${_likersSummary(otherNames, likedByMe)}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              if (canDelete) IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(context)),
            ],
          ),
        ],
      ),
    );
  }

  // "You", "You and Bob", "You, Bob and 3 others" — `others` excludes the viewer (backend does that).
  String _likersSummary(List<String> others, bool likedByMe) {
    final list = likedByMe ? ['You', ...others] : others;
    if (list.isEmpty) return '';
    if (list.length == 1) return list[0];
    if (list.length == 2) return '${list[0]} and ${list[1]}';
    if (list.length == 3) return '${list[0]}, ${list[1]} and ${list[2]}';
    return '${list[0]}, ${list[1]} and ${list.length - 2} others';
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool canDelete;
  final Future<void> Function() onChanged;
  const _AnnouncementCard({super.key, required this.item, required this.canDelete, required this.onChanged});

  Future<void> _delete(BuildContext context) async {
    if (!await _confirm(context, "Delete this announcement? This can't be undone.")) return;
    try {
      await AnnouncementApi.delete(item['id']);
      await onChanged();
    } catch (e) {
      if (context.mounted) _snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FeedCard(
      accent: kOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedHead(kind: 'Announcement', name: item['createdByName'], role: item['createdByRole'], createdAt: item['createdAt']),
          const SizedBox(height: 6),
          Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(item['message'] ?? ''),
          if (canDelete)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _delete(context), child: const Text('Delete')),
            ),
        ],
      ),
    );
  }
}

const _submissionLabel = {'SUBMITTED': 'Submitted', 'LATE': 'Submitted late', 'GRADED': 'Graded'};

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AssignmentCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    // Students hand work in; the assignment's author (or any admin) reviews and grades it.
    final canReview = auth.isAdmin || item['teacherId'] == auth.userId;
    return _FeedCard(
      accent: const Color(0xFF1C8A4B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedHead(kind: 'Assignment', name: item['teacherName'], role: item['authorRole'], createdAt: item['createdAt']),
          const SizedBox(height: 6),
          Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
          if ((item['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item['description']),
          ],
          const SizedBox(height: 4),
          Text('Due ${fmtDateTime(item['dueDate'])}', style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
          if (item['attachmentUrl'] != null)
            TextButton.icon(
              onPressed: () => _openFile(item['attachmentUrl']),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Open assignment PDF'),
            ),
          if (auth.isStudent) _StudentSubmission(assignment: item),
          if (canReview) _ReviewSubmissions(assignmentId: item['id']),
        ],
      ),
    );
  }
}

/// Student side of an assignment: hand in a file and/or a written answer, resubmit until it is
/// graded, then see the grade and feedback. Mirrors the web's StudentSubmission.
class _StudentSubmission extends StatefulWidget {
  final Map<String, dynamic> assignment;
  const _StudentSubmission({required this.assignment});

  @override
  State<_StudentSubmission> createState() => _StudentSubmissionState();
}

class _StudentSubmissionState extends State<_StudentSubmission> {
  Map<String, dynamic>? _submission;
  bool _loaded = false;
  bool _open = false;
  final _text = TextEditingController();
  String? _filePath;
  String? _fileName;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AssignmentApi.mySubmission(widget.assignment['id']).then((s) {
      if (!mounted) return;
      setState(() {
        _submission = s;
        _text.text = s?['textAnswer'] ?? '';
        _loaded = true;
      });
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await AssignmentApi.submit(widget.assignment['id'], filePath: _filePath, textAnswer: _text.text.trim());
      setState(() {
        _submission = saved;
        _filePath = null;
        _fileName = null;
        _open = false;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final s = _submission;
    final graded = s?['status'] == 'GRADED';
    final pastDue = DateTime.parse(widget.assignment['dueDate']).isBefore(DateTime.now());
    final canSubmit = _filePath != null || _text.text.trim().isNotEmpty || s?['fileUrl'] != null;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s != null)
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusPill(_submissionLabel[s['status']] ?? s['status']),
              Text('Submitted ${fmtDateTime(s['submittedAt'])}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          if (graded) ...[
            const SizedBox(height: 6),
            Text('Grade: ${s!['grade']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            if ((s['feedback'] ?? '').toString().isNotEmpty) Text(s['feedback']),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: InfoBanner.error(_error!)),
          if (!graded && !_open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FilledButton(onPressed: () => setState(() => _open = true), child: Text(s != null ? 'Resubmit' : 'Submit work')),
            ),
          if (!graded && _open) ...[
            const SizedBox(height: 6),
            if (pastDue) InfoBanner.warn('The due date has passed, so this will be marked as late.'),
            TextButton.icon(
              onPressed: () async {
                final res = await FilePicker.platform.pickFiles();
                final f = res?.files.single;
                if (f?.path != null) {
                  setState(() {
                    _filePath = f!.path;
                    _fileName = f.name;
                  });
                }
              },
              icon: const Icon(Icons.attach_file, size: 16),
              label: Text(_fileName ?? (s?['fileUrl'] != null ? 'Replace file (optional — keeps your current file)' : 'Attach file')),
            ),
            TextField(
              controller: _text,
              maxLines: 3,
              maxLength: 4000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Written answer'),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _busy ? null : () => setState(() => _open = false), child: const Text('Cancel')),
              const SizedBox(width: 6),
              FilledButton(onPressed: _busy || !canSubmit ? null : _submit, child: Text(_busy ? 'Submitting...' : 'Submit')),
            ]),
          ],
          if (!_open && s?['fileUrl'] != null)
            TextButton.icon(
              onPressed: () => _openFile(s!['fileUrl']),
              icon: const Icon(Icons.insert_drive_file_outlined, size: 16),
              label: const Text('Your file'),
            ),
          if (!_open && (s?['textAnswer'] ?? '').toString().isNotEmpty) Text(s!['textAnswer'], style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Author / admin side: every student's submission for this assignment, with grading.
class _ReviewSubmissions extends StatefulWidget {
  final int assignmentId;
  const _ReviewSubmissions({required this.assignmentId});

  @override
  State<_ReviewSubmissions> createState() => _ReviewSubmissionsState();
}

class _ReviewSubmissionsState extends State<_ReviewSubmissions> {
  bool _open = false;
  List<dynamic>? _submissions;
  String? _error;

  Future<void> _toggle() async {
    final next = !_open;
    setState(() {
      _open = next;
      _error = null;
    });
    if (!next) return;
    try {
      final s = await AssignmentApi.submissions(widget.assignmentId);
      if (mounted) setState(() => _submissions = s);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(onPressed: _toggle, child: Text(_open ? 'Hide submissions' : 'View submissions')),
        if (_open && _error != null) InfoBanner.error(_error!),
        if (_open && _submissions == null && _error == null) const Padding(padding: EdgeInsets.all(8), child: LoadingView()),
        if (_open && _submissions != null && _submissions!.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('No submissions yet.', style: TextStyle(color: Colors.grey))),
        if (_open && _submissions != null)
          ..._submissions!.map((s) => _SubmissionRow(
                key: ValueKey(s['id']),
                assignmentId: widget.assignmentId,
                submission: s,
                onGraded: (updated) => setState(() {
                  _submissions = _submissions!.map((x) => x['id'] == updated['id'] ? updated : x).toList();
                }),
              )),
      ],
    );
  }
}

class _SubmissionRow extends StatefulWidget {
  final int assignmentId;
  final Map<String, dynamic> submission;
  final ValueChanged<Map<String, dynamic>> onGraded;
  const _SubmissionRow({super.key, required this.assignmentId, required this.submission, required this.onGraded});

  @override
  State<_SubmissionRow> createState() => _SubmissionRowState();
}

class _SubmissionRowState extends State<_SubmissionRow> {
  late final _gradeController = TextEditingController(text: widget.submission['grade']?.toString() ?? '');
  late final _feedbackController = TextEditingController(text: widget.submission['feedback'] ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await AssignmentApi.grade(
        widget.assignmentId,
        widget.submission['id'],
        _gradeController.text.trim(),
        _feedbackController.text.trim(),
      );
      widget.onGraded(updated);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grade saved')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final graded = s['status'] == 'GRADED';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(fmtDateTime(s['submittedAt']), style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
              ]),
            ),
            StatusPill(graded ? 'Graded: ${s['grade']}' : (_submissionLabel[s['status']] ?? s['status'])),
          ]),
          if (s['fileUrl'] != null)
            TextButton.icon(
              onPressed: () => _openFile(s['fileUrl']),
              icon: const Icon(Icons.insert_drive_file_outlined, size: 16),
              label: const Text('Open submitted file', style: TextStyle(fontSize: 12)),
            ),
          if ((s['textAnswer'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(s['textAnswer'], style: const TextStyle(fontSize: 13))),
          if (_error != null) InfoBanner.error(_error!),
          Row(children: [
            SizedBox(
              width: 96,
              child: TextField(
                controller: _gradeController,
                maxLength: 50,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Grade', hintText: '18/20 or A', counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _feedbackController,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Feedback (optional)', counterText: ''),
              ),
            ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy || _gradeController.text.trim().isEmpty ? null : _save,
              child: Text(_busy ? 'Saving...' : (graded ? 'Update grade' : 'Save grade')),
            ),
          ),
        ],
      ),
    );
  }
}
