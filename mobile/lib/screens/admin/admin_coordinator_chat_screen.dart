import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/chat_thread.dart';
import '../../widgets/common.dart';

/// Private 1:1 messaging with each coordinator (Admin<->Coordinator only — see backend
/// DirectMessageService), with optional file attachments. Mirrors AdminCoordinatorChat.jsx.
class AdminCoordinatorChatScreen extends StatefulWidget {
  const AdminCoordinatorChatScreen({super.key});

  @override
  State<AdminCoordinatorChatScreen> createState() => _AdminCoordinatorChatScreenState();
}

class _AdminCoordinatorChatScreenState extends State<AdminCoordinatorChatScreen> {
  List<dynamic> _coordinators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UserApi.byRole('COORDINATOR').then((c) {
      if (mounted) setState(() {
        _coordinators = c;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_coordinators.isEmpty) return const EmptyState('No coordinator accounts yet.');
    final userId = context.read<AuthState>().userId!;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _coordinators.length,
      itemBuilder: (context, i) {
        final c = _coordinators[i];
        return Card(
          child: ListTile(
            title: Text(c['name']),
            subtitle: Text(c['email']),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(c['name'])),
                body: ChatThreadWidget(
                  currentUserId: userId,
                  allowAttachments: true,
                  loadHistory: () => DirectMessageApi.history(c['id']),
                  send: (content, path) => DirectMessageApi.send(c['id'], content, attachmentPath: path),
                  emptyText: 'No messages yet with ${c['name']}.',
                ),
              ),
            )),
          ),
        );
      },
    );
  }
}
