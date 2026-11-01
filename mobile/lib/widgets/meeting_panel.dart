import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/endpoints.dart';
import '../state/auth_state.dart';
import 'common.dart';

/// The class meeting for one session. The teacher starts the class by adding a Zoom / Google Meet
/// link; everyone else gets a "Join meet" button that unlocks 5 minutes before the scheduled start
/// (joinOpensAt, computed server-side). Mirrors the web's MeetingPanel.jsx.
const _providerLabel = {'ZOOM': 'Zoom', 'GOOGLE_MEET': 'Google Meet'};

class MeetingPanelWidget extends StatefulWidget {
  final Map<String, dynamic> session;
  final ValueChanged<Map<String, dynamic>> onChanged;

  /// Called once the join window opens, to fetch the link the server withholds until then.
  final VoidCallback? onRefresh;

  const MeetingPanelWidget({super.key, required this.session, required this.onChanged, this.onRefresh});

  @override
  State<MeetingPanelWidget> createState() => _MeetingPanelWidgetState();
}

class _MeetingPanelWidgetState extends State<MeetingPanelWidget> {
  bool _busy = false;
  Timer? _tick;
  bool _refreshRequested = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the join window every 15s so "Join meet" unlocks on time without a manual reload.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(MeetingPanelWidget old) {
    super.didUpdateWidget(old);
    if (old.session['id'] != widget.session['id'] || widget.session['meetingLink'] != null) _refreshRequested = false;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _showError(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editLink() async {
    final controller = TextEditingController(text: widget.session['meetingLink'] ?? '');
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zoom or Google Meet link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://meet.google.com/abc-defg-hij'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (link == null || link.isEmpty) return;
    setState(() => _busy = true);
    try {
      final updated = await SessionApi.setMeetingLink(widget.session['id'], link);
      widget.onChanged(updated);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(title: const Text('Remove the meeting link from this class?'), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
      ]),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final updated = await SessionApi.clearMeetingLink(widget.session['id']);
      widget.onChanged(updated);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final s = widget.session;
    final isTeacher = auth.isTeacher && auth.userId == s['teacherId'];
    final now = DateTime.now();
    final opensAt = DateTime.parse(s['joinOpensAt']).toLocal();
    final endsAt = DateTime.parse(s['scheduledEnd']).toLocal();
    final inactive = s['status'] == 'CANCELLED' || s['status'] == 'COMPLETED';
    final ended = inactive || now.isAfter(endsAt);
    final windowOpen = !inactive && !now.isBefore(opensAt) && now.isBefore(endsAt);
    final link = s['meetingLink'] as String?;
    final hasLink = s['hasMeetingLink'] == true;

    final provider = _providerLabel[s['meetingProvider']];

    // The server hides the link from students/coordinators until the window opens; once it does
    // (by our clock), re-fetch once so the button turns on by itself.
    if (!isTeacher && windowOpen && hasLink && (link == null || link.isEmpty) && !_refreshRequested && widget.onRefresh != null) {
      _refreshRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onRefresh?.call());
    }

    if (isTeacher) {
      if (inactive && link == null) {
        return Text('This class is ${(s['status'] as String).toLowerCase()}.', style: const TextStyle(color: Colors.grey));
      }
      if (link != null && link.isNotEmpty) {
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!ended)
              FilledButton.icon(
                onPressed: () => _openLink(link),
                icon: const Icon(Icons.videocam, size: 18),
                label: Text(provider == null ? 'Start class' : 'Start class on $provider'),
              ),
            if (!inactive)
              TextButton(onPressed: _busy ? null : _editLink, child: const Text('Change link')),
            if (!inactive) TextButton(onPressed: _busy ? null : _removeLink, child: const Text('Remove')),
            if (ended) const Text('This class has ended.', style: TextStyle(color: Colors.grey)),
          ],
        );
      }
      return Row(
        children: [
          FilledButton(onPressed: _busy ? null : _editLink, child: const Text('Start class')),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Add your Zoom or Google Meet link', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      );
    }

    if (ended) {
      return Text(
        s['status'] == 'CANCELLED' ? 'This class was cancelled.' : 'This class has ended.',
        style: const TextStyle(color: Colors.grey),
      );
    }
    if (!hasLink) {
      return const Text("The teacher hasn't added a meeting link yet.", style: TextStyle(color: Colors.grey));
    }
    if (windowOpen && link != null && link.isNotEmpty) {
      return FilledButton.icon(
        onPressed: () => _openLink(link),
        icon: const Icon(Icons.videocam, size: 18),
        label: Text(provider == null ? 'Join meet' : 'Join meet ($provider)'),
      );
    }
    return Row(
      children: [
        const FilledButton(onPressed: null, child: Text('Join meet')),
        const SizedBox(width: 10),
        Expanded(child: Text('Opens 5 minutes before class, at ${fmtDateTime(s['joinOpensAt'])}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
      ],
    );
  }
}
