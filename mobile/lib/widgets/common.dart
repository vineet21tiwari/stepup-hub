import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../theme.dart';

/// Uploaded files come back from the backend as relative paths (e.g. "/uploads/resumes/xyz.pdf").
String fileUrl(String? path) => path == null ? '' : '$apiBaseUrl$path';

bool isImagePath(String path) => RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(path);

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

class RolePill extends StatelessWidget {
  final String role;
  const RolePill(this.role, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(gradient: kBrandGradient, borderRadius: BorderRadius.all(Radius.circular(999))),
      child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

/// A small pill, e.g. "3 pending" — not a status, just a neutral badge.
class CountPill extends StatelessWidget {
  final String text;
  const CountPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

String fmtRange(String? startIso, String? endIso) {
  if (startIso == null || endIso == null) return '-';
  final start = DateTime.parse(startIso).toLocal();
  final end = DateTime.parse(endIso).toLocal();
  final dateFmt = DateFormat('EEE, MMM d');
  final timeFmt = DateFormat('h:mm a');
  return '${dateFmt.format(start)}, ${timeFmt.format(start)} - ${timeFmt.format(end)}';
}

String fmtTimeRange(String? startIso, String? endIso) {
  if (startIso == null || endIso == null) return '-';
  final start = DateTime.parse(startIso).toLocal();
  final end = DateTime.parse(endIso).toLocal();
  return '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
}

String fmtDateTime(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.parse(iso).toLocal();
  return DateFormat('EEE, MMM d, h:mm a').format(d);
}

String fmtDate(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.parse(iso).toLocal();
  return DateFormat('EEEE, MMM d, yyyy').format(d);
}

String fmtTime(String? iso) {
  if (iso == null) return '-';
  return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal());
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Prefer the next few upcoming SCHEDULED sessions; if none, fall back to the most recent past ones
/// — a dashboard should never sit empty just because nothing's left today. Mirrors the web's
/// `pickRecentOrUpcoming` helper.
class RecentOrUpcoming {
  final List<dynamic> items;
  final bool isUpcoming;
  RecentOrUpcoming(this.items, this.isUpcoming);
}

RecentOrUpcoming pickRecentOrUpcoming(List<dynamic> sessions, {int upcomingLimit = 5, int recentLimit = 3}) {
  final now = DateTime.now();
  final scheduled = sessions.where((s) => s['status'] == 'SCHEDULED').toList();
  final upcoming = scheduled.where((s) => DateTime.parse(s['scheduledStart']).toLocal().isAfter(now)).toList()
    ..sort((a, b) => (a['scheduledStart'] as String).compareTo(b['scheduledStart'] as String));
  if (upcoming.isNotEmpty) return RecentOrUpcoming(upcoming.take(upcomingLimit).toList(), true);
  final recent = scheduled.where((s) => !DateTime.parse(s['scheduledStart']).toLocal().isAfter(now)).toList()
    ..sort((a, b) => (b['scheduledStart'] as String).compareTo(a['scheduledStart'] as String));
  return RecentOrUpcoming(recent.take(recentLimit).toList(), false);
}

/// Collapses a list of EnrollmentRequestDto into one entry per batchId (a weekly-commitment booking
/// creates one request per dated occurrence, all sharing a batchId) — deciding on any one of them
/// approves/rejects the whole batch server-side, so approval UIs only need to show one card.
class BatchGroup {
  final Map<String, dynamic> representative;
  final int count;
  BatchGroup(this.representative, this.count);
}

List<BatchGroup> groupEnrollmentRequests(List<dynamic> requests) {
  final byKey = <String, List<dynamic>>{};
  for (final r in requests) {
    byKey.putIfAbsent(r['batchId'] ?? 'single-${r['id']}', () => []).add(r);
  }
  return byKey.values.map((items) {
    final sorted = items.toList()..sort((a, b) => (a['slotStart'] as String).compareTo(b['slotStart'] as String));
    return BatchGroup(sorted.first, items.length);
  }).toList();
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const InfoBanner(this.text, {super.key, required this.background, required this.foreground});

  factory InfoBanner.error(String text) => InfoBanner(text, background: const Color(0xFFFDEAEA), foreground: const Color(0xFFC62828));
  factory InfoBanner.warn(String text) => InfoBanner(text, background: const Color(0xFFFFF3E0), foreground: const Color(0xFFB8720A));
  factory InfoBanner.info(String text) => InfoBanner(text, background: const Color(0xFFE8F1FC), foreground: kNavyDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(kRadiusSm)),
      child: Text(text, style: TextStyle(color: foreground)),
    );
  }
}

/// A stat tile with an accent bar, used on every role's dashboard.
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  const StatCard(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 54,
            margin: const EdgeInsets.only(left: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kNavy, kOrange]),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  Text(label,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w600),
                      maxLines: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
