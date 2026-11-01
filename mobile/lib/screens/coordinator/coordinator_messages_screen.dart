import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/chat_thread.dart';
import '../../widgets/common.dart';

/// Private 1:1 messaging with admin, with optional file attachments. Mirrors CoordinatorMessages.jsx.
class CoordinatorMessagesScreen extends StatefulWidget {
  const CoordinatorMessagesScreen({super.key});

  @override
  State<CoordinatorMessagesScreen> createState() => _CoordinatorMessagesScreenState();
}

class _CoordinatorMessagesScreenState extends State<CoordinatorMessagesScreen> {
  List<dynamic> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UserApi.byRole('ADMIN').then((a) {
      if (mounted) setState(() {
        _admins = a;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_admins.isEmpty) return const EmptyState('No admin accounts found.');
    final userId = context.read<AuthState>().userId!;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _admins.length,
      itemBuilder: (context, i) {
        final a = _admins[i];
        return Card(
          child: ListTile(
            title: Text(a['name']),
            subtitle: Text(a['email']),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(a['name'])),
                body: ChatThreadWidget(
                  currentUserId: userId,
                  allowAttachments: true,
                  loadHistory: () => DirectMessageApi.history(a['id']),
                  send: (content, path) => DirectMessageApi.send(a['id'], content, attachmentPath: path),
                  emptyText: 'No messages yet with ${a['name']}.',
                ),
              ),
            )),
          ),
        );
      },
    );
  }
}
