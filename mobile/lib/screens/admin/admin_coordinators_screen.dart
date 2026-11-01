import 'package:flutter/material.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

/// Course-level coordinator assignment — a course can have several coordinators, each covering
/// every class in it. Mirrors the web's AdminCoordinators.jsx.
class AdminCoordinatorsScreen extends StatefulWidget {
  const AdminCoordinatorsScreen({super.key});

  @override
  State<AdminCoordinatorsScreen> createState() => _AdminCoordinatorsScreenState();
}

class _AdminCoordinatorsScreenState extends State<AdminCoordinatorsScreen> {
  List<dynamic> _courses = [];
  List<dynamic> _allCoordinators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([CourseApi.list(), UserApi.byRole('COORDINATOR')]);
    if (!mounted) return;
    setState(() {
      _courses = results[0];
      _allCoordinators = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [Tab(text: 'By course'), Tab(text: 'By coordinator')],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _ByCourseTab(courses: _courses, allCoordinators: _allCoordinators),
              _ByCoordinatorTab(coordinators: _allCoordinators),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ByCourseTab extends StatefulWidget {
  final List<dynamic> courses;
  final List<dynamic> allCoordinators;
  const _ByCourseTab({required this.courses, required this.allCoordinators});

  @override
  State<_ByCourseTab> createState() => _ByCourseTabState();
}

class _ByCourseTabState extends State<_ByCourseTab> {
  Map<String, dynamic>? _selected;
  List<dynamic> _assigned = [];
  bool _busy = false;
  String? _error;

  Future<void> _select(Map<String, dynamic> c) async {
    setState(() {
      _selected = c;
      _error = null;
    });
    final list = await CourseApi.coordinatorsForCourse(c['id']);
    if (mounted) setState(() => _assigned = list);
  }

  Future<void> _assign(int coordinatorId) async {
    setState(() => _busy = true);
    try {
      await CourseApi.assignCoordinator(_selected!['id'], coordinatorId);
      await _select(_selected!);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unassign(int coordinatorId) async {
    setState(() => _busy = true);
    try {
      await CourseApi.unassignCoordinator(_selected!['id'], coordinatorId);
      await _select(_selected!);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.allCoordinators.where((c) => !_assigned.any((a) => a['id'] == c['id'])).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: _selected,
          decoration: const InputDecoration(labelText: 'Select a course'),
          items: widget.courses.map<DropdownMenuItem<Map<String, dynamic>>>((c) => DropdownMenuItem(value: c, child: Text(c['title']))).toList(),
          onChanged: (c) => c == null ? null : _select(c),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          if (_error != null) InfoBanner.error(_error!),
          const Text('Assigned coordinators', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          if (_assigned.isEmpty) const EmptyState('No coordinators assigned yet.'),
          ..._assigned.map((c) => ListTile(
                title: Text(c['name']),
                subtitle: Text(c['email']),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: _busy ? null : () => _unassign(c['id'])),
              )),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: null,
                  decoration: const InputDecoration(labelText: 'Add coordinator'),
                  items: available.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'], child: Text(c['name']))).toList(),
                  onChanged: _busy ? null : (v) => v == null ? null : _assign(v),
                ),
              ),
            ]),
          ],
        ],
      ],
    );
  }
}

class _ByCoordinatorTab extends StatefulWidget {
  final List<dynamic> coordinators;
  const _ByCoordinatorTab({required this.coordinators});

  @override
  State<_ByCoordinatorTab> createState() => _ByCoordinatorTabState();
}

class _ByCoordinatorTabState extends State<_ByCoordinatorTab> {
  final Map<int, dynamic> _coursesByCoordinator = {};

  @override
  void initState() {
    super.initState();
    for (final c in widget.coordinators) {
      CoordinatorApi.coursesFor(c['id']).then((list) {
        if (mounted) setState(() => _coursesByCoordinator[c['id']] = list);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.coordinators.isEmpty) return const EmptyState('No coordinator accounts yet — create one under Users.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.coordinators.length,
      itemBuilder: (context, i) {
        final c = widget.coordinators[i];
        final courses = _coursesByCoordinator[c['id']];
        return Card(
          child: ListTile(
            title: Text(c['name']),
            subtitle: Text(courses == null
                ? 'Loading...'
                : courses.isEmpty
                    ? 'Not assigned to any course yet'
                    : 'Assigned to: ${courses.map((x) => x['title']).join(', ')}'),
          ),
        );
      },
    );
  }
}
