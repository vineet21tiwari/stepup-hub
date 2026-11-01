import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import 'chat_thread.dart';
import 'common.dart';

/// Marks this course's unread chat notifications as read (opening its chat counts as reading it).
Future<void> markCourseChatRead(int courseId) async {
  try {
    final items = await NotificationApi.list();
    final toMark = items.where((n) => n['type'] == 'NEW_CHAT_MESSAGE' && n['read'] != true && n['relatedEntity'] == 'COURSE:$courseId');
    await Future.wait(toMark.map((n) => NotificationApi.markRead(n['id'])));
  } catch (_) {
    // best effort — the badge just stays until next time
  }
}

/// Course ids with unread chat messages, from a notifications list.
Set<int> unreadChatCourseIds(List<dynamic> notifications) => notifications
    .where((n) => n['type'] == 'NEW_CHAT_MESSAGE' && n['read'] != true)
    .map((n) => int.tryParse((n['relatedEntity'] as String? ?? '').split(':').last))
    .whereType<int>()
    .toSet();

/// Full-screen chat for one course (one thread covering every class in it).
Future<void> openCourseChat(BuildContext context, int courseId, String courseTitle) {
  markCourseChatRead(courseId);
  final userId = context.read<AuthState>().userId!;
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text('$courseTitle chat')),
      body: ChatThreadWidget(
        currentUserId: userId,
        loadHistory: () => ChatApi.history(courseId),
        send: (content, _) => ChatApi.send(courseId, content ?? ''),
        emptyText: 'No messages yet. Say hello to the course!',
        hintText: 'Message the course...',
      ),
    ),
  ));
}

/// Pick a course to chat in — every course the user has classes in, with a dot on ones that have
/// unread messages. Mirrors the web's FloatingChat course list.
class CourseChatListScreen extends StatefulWidget {
  final List<dynamic> notifications;
  const CourseChatListScreen({super.key, required this.notifications});

  @override
  State<CourseChatListScreen> createState() => _CourseChatListScreenState();
}

class _CourseChatListScreenState extends State<CourseChatListScreen> {
  List<Map<String, dynamic>>? _courses;
  late Set<int> _unread = unreadChatCourseIds(widget.notifications);
  String? _error;

  @override
  void initState() {
    super.initState();
    SessionApi.mine().then((sessions) {
      final byId = <int, Map<String, dynamic>>{};
      for (final s in sessions) {
        byId.putIfAbsent(s['courseId'], () => {'courseId': s['courseId'], 'courseTitle': s['courseTitle']});
      }
      final list = byId.values.toList()..sort((a, b) => (a['courseTitle'] as String).compareTo(b['courseTitle'] as String));
      if (mounted) setState(() => _courses = list);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course chat')),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(16), child: InfoBanner.error(_error!))
          : _courses == null
              ? const LoadingView()
              : _courses!.isEmpty
                  ? const EmptyState('No courses to chat in yet.', icon: Icons.forum_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _courses!.length,
                      itemBuilder: (context, i) {
                        final c = _courses![i];
                        final unread = _unread.contains(c['courseId']);
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.forum_outlined),
                            title: Text(c['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            trailing: unread
                                ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              setState(() => _unread = {..._unread}..remove(c['courseId']));
                              openCourseChat(context, c['courseId'], c['courseTitle'] ?? '');
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
