import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

/// Admin: every teacher's active weekly slot series. Admin can cancel a whole series, booked slots
/// included (their classes are cancelled and students notified). Mirrors AdminSlotSeries.jsx.
class AdminSlotSeriesScreen extends StatefulWidget {
  const AdminSlotSeriesScreen({super.key});

  @override
  State<AdminSlotSeriesScreen> createState() => _AdminSlotSeriesScreenState();
}

class _AdminSlotSeriesScreenState extends State<AdminSlotSeriesScreen> {
  List<dynamic>? _series;
  String _query = '';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await TeacherApi.allSeries();
      if (mounted) setState(() => _series = s);
    } catch (e) {
      if (mounted) setState(() => _series = []);
    }
  }

  Future<void> _cancel(Map<String, dynamic> s) async {
    final booked = s['bookedSlots'] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this series?'),
        content: Text(booked > 0
            ? '$booked slot(s) are booked. Their classes will be cancelled and students notified.'
            : 'Every slot in this series will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel series')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = s['recurrenceGroupId']);
    try {
      final res = await TeacherApi.adminCancelSeries(s['recurrenceGroupId']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cancelled ${res['cancelled']} slot(s)${(res['bookedCancelled'] ?? 0) > 0 ? ', including ${res['bookedCancelled']} booked' : ''}.'),
        ));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _series;
    if (all == null) return const LoadingView();
    final q = _query.toLowerCase();
    final list = all
        .where((s) => q.isEmpty || '${s['teacherName']} ${s['courseTitle']}'.toLowerCase().contains(q))
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search teacher or course'),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty) const EmptyState('No active slot series.'),
          for (final s in list)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s['courseTitle'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    CountPill(s['sessionType'] == 'GROUP' ? 'Group' : '1-on-1'),
                  ]),
                  const SizedBox(height: 4),
                  Text('Teacher: ${s['teacherName']}', style: const TextStyle(color: Colors.grey)),
                  Text('${fmtDate(s['firstStart'])} → ${fmtDate(s['lastStart'])}', style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text('${s['totalSlots']} slots · ${s['bookedSlots']} booked', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _busyId == s['recurrenceGroupId'] ? null : () => _cancel(Map<String, dynamic>.from(s)),
                      icon: const Icon(Icons.event_busy, size: 18, color: Color(0xFFC62828)),
                      label: Text(_busyId == s['recurrenceGroupId'] ? 'Cancelling...' : 'Cancel series',
                          style: const TextStyle(color: Color(0xFFC62828))),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
