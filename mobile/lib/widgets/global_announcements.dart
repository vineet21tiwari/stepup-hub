import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/endpoints.dart';
import '../theme.dart';

const _dismissedKey = 'stepup_dismissed_announcements';

/// Platform-wide announcements shown as a dismissible banner strip above the app content on every
/// tab — mirrors the web's GlobalAnnouncements.jsx. Dismissals persist locally (per device), same
/// as the web's localStorage-backed behavior.
class GlobalAnnouncementsBanner extends StatefulWidget {
  const GlobalAnnouncementsBanner({super.key});

  @override
  State<GlobalAnnouncementsBanner> createState() => _GlobalAnnouncementsBannerState();
}

class _GlobalAnnouncementsBannerState extends State<GlobalAnnouncementsBanner> {
  List<dynamic> _announcements = [];
  List<int> _dismissed = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadDismissed().then((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dismissedKey);
    if (raw != null) {
      try {
        _dismissed = List<int>.from(jsonDecode(raw));
      } catch (_) {
        _dismissed = [];
      }
    }
  }

  Future<void> _load() async {
    try {
      final data = await AnnouncementApi.global();
      if (mounted) setState(() => _announcements = data);
    } catch (_) {
      // ignore transient failures during polling
    }
  }

  Future<void> _dismiss(int id) async {
    setState(() => _dismissed = [..._dismissed, id]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, jsonEncode(_dismissed));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _announcements.where((a) => !_dismissed.contains(a['id'])).take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      children: visible
          .map<Widget>((a) => Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kOrange.withValues(alpha: 0.12),
                  border: Border.all(color: kOrange),
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                          children: [
                            TextSpan(text: '${a['title']}  ', style: const TextStyle(fontWeight: FontWeight.w800, color: kOrangeDark)),
                            TextSpan(text: a['message']),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _dismiss(a['id']),
                      child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close, size: 16)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
