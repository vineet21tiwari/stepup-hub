import 'package:flutter/material.dart';
import 'admin_announcements_screen.dart';
import 'admin_coordinator_chat_screen.dart';
import 'admin_coordinators_screen.dart';
import 'admin_site_content_screen.dart';
import 'admin_tasks_screen.dart';
import 'admin_users_screen.dart';

/// Hub for admin destinations that don't fit the bottom nav bar.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem('Users', 'Create accounts, reset passwords, manage access', Icons.people_outline, const AdminUsersScreen()),
      _MoreItem('Coordinators', 'Assign coordinators to courses', Icons.badge_outlined, const AdminCoordinatorsScreen()),
      _MoreItem('Coordinator messages', 'Private chat with each coordinator', Icons.forum_outlined, const AdminCoordinatorChatScreen()),
      _MoreItem('Tasks', 'Assign deadline-driven tasks to coordinators', Icons.task_outlined, const AdminTasksScreen()),
      _MoreItem('Announcements', 'Post global or course announcements', Icons.campaign_outlined, const AdminAnnouncementsScreen()),
      _MoreItem('Website content', 'Edit the public pages and testimonials', Icons.web_outlined, const AdminSiteContentScreen()),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final item = items[i];
        return Card(
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(item.title)), body: item.screen))),
          ),
        );
      },
    );
  }
}

class _MoreItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
  _MoreItem(this.title, this.subtitle, this.icon, this.screen);
}
