import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import '../widgets/course_chat.dart';
import '../widgets/global_announcements.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/common.dart';
import '../theme.dart';
import 'profile_screen.dart';
import 'change_requests_screen.dart';
import 'sessions_screen.dart';
import 'student/student_home_screen.dart';
import 'student/browse_courses_screen.dart';
import 'student/my_bookings_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'teacher/teacher_teaching_screen.dart';
import 'teacher/teacher_approvals_screen.dart';
import 'coordinator/coordinator_home_screen.dart';
import 'coordinator/coordinator_messages_screen.dart';
import 'coordinator/coordinator_tasks_screen.dart';
import 'admin/admin_home_screen.dart';
import 'admin/admin_courses_screen.dart';
import 'admin/admin_approvals_screen.dart';
import 'admin/admin_more_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  List<dynamic> _notifications = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Same 20s cadence as the web NotificationBell / FloatingChat.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _loadNotifications());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final n = await NotificationApi.list();
      if (mounted) setState(() => _notifications = n);
    } catch (_) {
      // ignore transient failures during polling
    }
  }

  void _goToTab(String key) {
    final tabs = _tabsForRole(context.read<AuthState>().role);
    final i = tabs.indexWhere((t) => t.key == key);
    setState(() => _index = i < 0 ? 0 : i);
  }

  Widget _badged(IconData icon, int count, VoidCallback onPressed, String tooltip) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: Icon(icon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final role = auth.role;
    final tabs = _tabsForRole(role);
    final index = _index < tabs.length ? _index : 0;
    final unread = _notifications.where((n) => n['read'] != true).length;
    final unreadChats = unreadChatCourseIds(_notifications).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        toolbarHeight: 62,
        title: Row(children: [
          const BrandLogo(size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'StepUp '),
                  TextSpan(text: 'Hub', style: TextStyle(color: kOrange)),
                ]),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
              ),
              Text(tabs[index].label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        actions: [
          _badged(Icons.forum_outlined, unreadChats, () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseChatListScreen(notifications: _notifications)));
            _loadNotifications();
          }, 'Course chat'),
          _badged(Icons.notifications_none, unread, () async {
            await showNotificationsSheet(context, role: role, onChanged: _loadNotifications, onGoToTab: _goToTab);
            _loadNotifications();
          }, 'Notifications'),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _openAccountSheet(auth),
              child: UserAvatar(auth.user?['name'], size: 36),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Column(
        children: [
          const GlobalAnnouncementsBanner(),
          Expanded(
            child: IndexedStack(
              index: index,
              children: tabs.map((t) => t.screen).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: kOrange.withValues(alpha: 0.18),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.icon, color: kOrangeDark),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }

  /// Account sheet behind the avatar: profile, change requests, theme, log out.
  Future<void> _openAccountSheet(AuthState auth) async {
    final user = auth.user ?? {};
    final role = auth.role;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              UserAvatar(user['name'], size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(user['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  RolePill(role ?? ''),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            if (role == 'TEACHER' || role == 'STUDENT' || role == 'ADMIN')
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Class change requests', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: const Text('Change requests')), body: const ChangeRequestsScreen()),
                  ));
                },
              ),
            const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: ThemeToggle(),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFC62828)),
              title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<AuthState>().logout();
              },
            ),
          ]),
        ),
      ),
    );
  }

  List<_Tab> _tabsForRole(String? role) {
    switch (role) {
      case 'STUDENT':
        return [
          _Tab('home', 'Home', Icons.home_outlined, const StudentHomeScreen()),
          _Tab('courses', 'Courses', Icons.menu_book_outlined, const BrowseCoursesScreen()),
          _Tab('bookings', 'Bookings', Icons.event_available_outlined, const MyBookingsScreen()),
          _Tab('classes', 'Classes', Icons.school_outlined, const SessionsScreen()),
        ];
      case 'TEACHER':
        return [
          _Tab('home', 'Home', Icons.home_outlined, const TeacherHomeScreen()),
          _Tab('teaching', 'Teaching', Icons.menu_book_outlined, const TeacherTeachingScreen()),
          _Tab('requests', 'Requests', Icons.fact_check_outlined, const TeacherApprovalsScreen()),
          _Tab('classes', 'Classes', Icons.school_outlined, const SessionsScreen()),
        ];
      case 'COORDINATOR':
        return [
          _Tab('home', 'Home', Icons.home_outlined, const CoordinatorHomeScreen()),
          _Tab('classes', 'Classes', Icons.school_outlined, const SessionsScreen()),
          _Tab('messages', 'Messages', Icons.forum_outlined, const CoordinatorMessagesScreen()),
          _Tab('tasks', 'Tasks', Icons.task_outlined, const CoordinatorTasksScreen()),
        ];
      case 'ADMIN':
        return [
          _Tab('home', 'Home', Icons.home_outlined, const AdminHomeScreen()),
          _Tab('admin-courses', 'Courses', Icons.menu_book_outlined, const AdminCoursesScreen()),
          _Tab('approvals', 'Approvals', Icons.fact_check_outlined, const AdminApprovalsScreen()),
          _Tab('classes', 'Classes', Icons.school_outlined, const SessionsScreen()),
          _Tab('more', 'More', Icons.more_horiz, const AdminMoreScreen()),
        ];
      default:
        return [_Tab('home', 'Home', Icons.home_outlined, const SizedBox())];
    }
  }
}

class _Tab {
  final String key;
  final String label;
  final IconData icon;
  final Widget screen;
  _Tab(this.key, this.label, this.icon, this.screen);
}
