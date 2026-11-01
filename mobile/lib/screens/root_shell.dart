import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import '../widgets/course_chat.dart';
import '../widgets/global_announcements.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/theme_toggle.dart';
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
    final role = context.watch<AuthState>().role;
    final tabs = _tabsForRole(role);
    final index = _index < tabs.length ? _index : 0;
    final unread = _notifications.where((n) => n['read'] != true).length;
    final unreadChats = unreadChatCourseIds(_notifications).length;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo.png', height: 32),
        actions: [
          const Padding(padding: EdgeInsets.only(right: 4), child: ThemeToggle()),
          _badged(Icons.forum_outlined, unreadChats, () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseChatListScreen(notifications: _notifications)));
            _loadNotifications();
          }, 'Course chat'),
          _badged(Icons.notifications_none, unread, () async {
            await showNotificationsSheet(context, role: role, onChanged: _loadNotifications, onGoToTab: _goToTab);
            _loadNotifications();
          }, 'Notifications'),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
        items: tabs.map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label)).toList(),
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
