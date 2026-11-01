import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

const Map<String, String> _statusLabel = {
  'PENDING_TEACHER': 'Under review',
  'PENDING_ADMIN': 'Under review',
  'APPROVED': 'Confirmed',
  'REJECTED_BY_TEACHER': 'Declined',
  'REJECTED_BY_ADMIN': 'Declined',
};
const _cancellable = ['PENDING_TEACHER', 'PENDING_ADMIN'];

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  int? _cancellingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await EnrollmentApi.mine();
    b.sort((a, c) => (c['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
    if (mounted) setState(() {
      _bookings = b;
      _loading = false;
    });
  }

  Future<void> _cancel(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(title: const Text('Cancel this booking request?'), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, cancel')),
      ]),
    );
    if (ok != true) return;
    setState(() => _cancellingId = id);
    try {
      await EnrollmentApi.cancel(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_bookings.isEmpty) return const EmptyState("You haven't requested any classes yet.");
    final groups = groupEnrollmentRequests(_bookings);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final b = g.representative;
          final status = b['status'] as String;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(b['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                          if (g.count > 1) ...[const SizedBox(width: 6), CountPill('${g.count} weekly classes')],
                        ]),
                        Text('with ${b['teacherName'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                        Text(fmtRange(b['slotStart'], b['slotEnd']), style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Column(children: [
                    StatusPill(_statusLabel[status] ?? status),
                    if (_cancellable.contains(status))
                      TextButton(
                        onPressed: _cancellingId == b['id'] ? null : () => _cancel(b['id']),
                        child: Text(_cancellingId == b['id'] ? '...' : 'Cancel', style: const TextStyle(fontSize: 12)),
                      ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
