import 'package:flutter/material.dart';
import '../api/endpoints.dart';
import '../screens/course_detail_screen.dart';
import 'common.dart';

/// Where a notification should take the user. Bottom-nav destinations are named so the shell can
/// switch tabs; course-scoped things open the course page. Mirrors the web NotificationBell's
/// `resolveRoute`.
class NotificationTarget {
  final String? tab; // 'home' | 'bookings' | 'requests' | 'approvals' | 'teaching'
  final int? courseId;
  const NotificationTarget({this.tab, this.courseId});
}

Future<NotificationTarget?> _resolve(Map<String, dynamic> n, String? role) async {
  final parts = (n['relatedEntity'] as String? ?? '').split(':');
  if (parts.length != 2) return null;
  final type = parts[0];
  final id = int.tryParse(parts[1]);
  switch (type) {
    case 'COURSE':
      return id == null ? null : NotificationTarget(courseId: id);
    case 'SESSION':
      if (id == null) return null;
      try {
        final s = await SessionApi.get(id);
        return NotificationTarget(courseId: s['courseId'] as int?);
      } catch (_) {
        return null;
      }
    case 'ENROLLMENT_REQUEST':
      if (role == 'ADMIN') return const NotificationTarget(tab: 'approvals');
      if (role == 'TEACHER') return const NotificationTarget(tab: 'requests');
      return const NotificationTarget(tab: 'bookings');
    case 'TEACHER_APPLICATION':
      return NotificationTarget(tab: role == 'ADMIN' ? 'approvals' : 'teaching');
    case 'ANNOUNCEMENT':
      // Only the announcement id is carried — look it up to see whether it's course-scoped.
      if (id != null) {
        try {
          final a = await AnnouncementApi.get(id);
          if (a['scope'] == 'COURSE' && a['courseId'] != null) return NotificationTarget(courseId: a['courseId'] as int);
        } catch (_) {}
      }
      return const NotificationTarget(tab: 'home');
    case 'ASSIGNMENT':
      if (id == null) return null;
      try {
        final a = await AssignmentApi.get(id);
        return NotificationTarget(courseId: a['courseId'] as int?);
      } catch (_) {
        return null;
      }
    default:
      return null;
  }
}

/// Shows the notification list. `onChanged` is called after something is marked read (so the shell
/// can refresh its badge); `onGoToTab` switches the bottom-nav tab for non-course destinations.
Future<void> showNotificationsSheet(
  BuildContext context, {
  required String? role,
  VoidCallback? onChanged,
  ValueChanged<String>? onGoToTab,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => _NotificationsSheet(role: role, onChanged: onChanged, onGoToTab: onGoToTab),
  );
}

class _NotificationsSheet extends StatefulWidget {
  final String? role;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onGoToTab;
  const _NotificationsSheet({this.role, this.onChanged, this.onGoToTab});

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await NotificationApi.list();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    if (n['read'] != true) {
      try {
        await NotificationApi.markRead(n['id']);
      } catch (_) {}
      widget.onChanged?.call();
      _load();
    }
    final target = await _resolve(n, widget.role);
    if (target == null || !mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    if (target.courseId != null) {
      navigator.push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: target.courseId!)));
    } else if (target.tab != null) {
      widget.onGoToTab?.call(target.tab!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlight = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _items.isEmpty
                    ? const EmptyState("You're all caught up.", icon: Icons.notifications_none)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final n = _items[i];
                            final unread = n['read'] != true;
                            return ListTile(
                              tileColor: unread ? highlight : null,
                              leading: unread
                                  ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                                  : const SizedBox(width: 8),
                              minLeadingWidth: 8,
                              title: Text(n['message'] ?? '', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.normal)),
                              subtitle: Text(fmtDateTime(n['createdAt'])),
                              onTap: () => _open(n),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
