import 'package:flutter/material.dart';
import '../api/endpoints.dart';
import '../widgets/class_change_panel.dart';
import '../widgets/common.dart';

/// Reschedule / cancel requests across the viewer's classes (admins see every one).
class ChangeRequestsScreen extends StatefulWidget {
  const ChangeRequestsScreen({super.key});

  @override
  State<ChangeRequestsScreen> createState() => _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends State<ChangeRequestsScreen> {
  List<dynamic>? _requests;
  String _tab = 'action';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await SessionApi.myChangeRequests();
      if (mounted) setState(() => _requests = r);
    } catch (e) {
      if (mounted) setState(() => _requests = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _requests;
    if (list == null) return const LoadingView();
    final action = list.where((r) => r['canDecide'] == true).toList();
    final pending = list.where((r) => r['status'] == 'PENDING' && r['canDecide'] != true).toList();
    final history = list.where((r) => r['status'] != 'PENDING').toList();
    final shown = _tab == 'action' ? action : (_tab == 'pending' ? pending : history);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Teacher requests need the student(s) and an admin to approve; student requests need the teacher and an admin. '
            'Changes are allowed only up to the day before the class.',
            style: TextStyle(color: Colors.grey, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'action', label: Text('To approve (${action.length})')),
              ButtonSegment(value: 'pending', label: Text('Waiting (${pending.length})')),
              const ButtonSegment(value: 'history', label: Text('History')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty) const EmptyState('Nothing here.', icon: Icons.swap_horiz),
          for (final r in shown) ChangeRequestCard(request: Map<String, dynamic>.from(r), showClass: true, onChanged: _load),
        ],
      ),
    );
  }
}
