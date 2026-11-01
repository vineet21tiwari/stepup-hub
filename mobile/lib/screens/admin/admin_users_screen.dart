import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/endpoints.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';

const _roleTabs = ['ALL', 'STUDENT', 'TEACHER', 'COORDINATOR', 'ADMIN'];

/// Every account on the platform — admin can create Admin/Coordinator accounts directly (students
/// and teachers self-signup), edit profiles, reset a password (generates a one-time temp password,
/// never shows the real one), and deactivate/reactivate. Mirrors the web's AdminUsers.jsx.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _roleFilter = 'ALL';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await UserApi.byRole();
    if (mounted) setState(() {
      _users = u;
      _loading = false;
    });
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _users.where((u) {
      if (_roleFilter != 'ALL' && u['role'] != _roleFilter) return false;
      if (q.isEmpty) return true;
      return (u['name'] as String).toLowerCase().contains(q) || (u['email'] as String).toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openCreate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _CreateUserSheet(onCreated: _load),
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Reset ${u['name']}'s password?"),
        content: const Text('Their current password will stop working immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final result = await UserApi.resetPassword(u['id']);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('New temporary password'),
          content: SelectableText(
            'Share this with ${u['name']} now — it will not be shown again:\n\n${result['tempPassword']}',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> u) async {
    if (u['active'] == true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Deactivate ${u['name']}?'),
          content: const Text("They won't be able to log in, and teachers will disappear from booking until reactivated."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Deactivate')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      if (u['active'] == true) {
        await UserApi.deactivate(u['id']);
      } else {
        await UserApi.reactivate(u['id']);
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openEdit(Map<String, dynamic> u) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _EditUserSheet(user: u, onSaved: _load),
    );
  }

  void _openTeacherDetails(Map<String, dynamic> u) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TeacherDetailsScreen(teacher: u)));
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthState>().userId;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _openCreate, icon: const Icon(Icons.add), label: const Text('New account')),
      body: _loading
          ? const LoadingView()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(hintText: 'Search by name or email...', prefixIcon: Icon(Icons.search)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _roleTabs
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(label: Text(r == 'ALL' ? 'All' : r[0] + r.substring(1).toLowerCase()), selected: _roleFilter == r, onSelected: (_) => setState(() => _roleFilter = r)),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final u = _filtered[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  RolePill(u['role'] ?? ''),
                                  if (u['role'] == 'TEACHER') ...[
                                    const SizedBox(width: 4),
                                    StatusPill(u['approved'] == true ? 'Approved' : 'Not approved'),
                                  ],
                                  if (u['active'] != true) ...[const SizedBox(width: 4), const StatusPill('Deactivated')],
                                ]),
                                Text('${u['email']}${(u['phone'] ?? '').toString().isEmpty ? '' : ' · ${u['phone']}'}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                                if ((u['extraInfo'] ?? '').toString().isNotEmpty)
                                  Text(u['extraInfo'], style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  if (u['role'] == 'TEACHER')
                                    OutlinedButton(onPressed: () => _openTeacherDetails(u), child: const Text('View details', style: TextStyle(fontSize: 12))),
                                  OutlinedButton(onPressed: () => _openEdit(u), child: const Text('Edit', style: TextStyle(fontSize: 12))),
                                  OutlinedButton(onPressed: () => _resetPassword(u), child: const Text('Reset password', style: TextStyle(fontSize: 12))),
                                  OutlinedButton(
                                    // You can't deactivate your own account.
                                    onPressed: u['id'] == myId && u['active'] == true ? null : () => _toggleActive(u),
                                    child: Text(u['active'] == true ? 'Deactivate' : 'Reactivate', style: const TextStyle(fontSize: 12)),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateUserSheet({required this.onCreated});

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _extraInfo = TextEditingController();
  String _role = 'COORDINATOR';
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await UserApi.create({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'phone': _phone.text.trim(),
        'role': _role,
        'extraInfo': _extraInfo.text.trim(),
      });
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create Admin / Coordinator account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          if (_error != null) InfoBanner.error(_error!),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'COORDINATOR', child: Text('Coordinator')),
              DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'COORDINATOR'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          TextField(controller: _password, decoration: const InputDecoration(labelText: 'Initial password'), obscureText: true),
          const SizedBox(height: 10),
          TextField(controller: _extraInfo, decoration: const InputDecoration(labelText: 'Title (optional)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating...' : 'Create account')),
        ],
      ),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onSaved;
  const _EditUserSheet({required this.user, required this.onSaved});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late final _name = TextEditingController(text: widget.user['name'] ?? '');
  late final _email = TextEditingController(text: widget.user['email'] ?? '');
  late final _phone = TextEditingController(text: widget.user['phone'] ?? '');
  late final _extraInfo = TextEditingController(text: widget.user['extraInfo'] ?? '');
  late bool _approved = widget.user['approved'] == true;
  bool _busy = false;
  String? _error;

  bool get _isTeacher => widget.user['role'] == 'TEACHER';

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _error = 'Name and email are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await UserApi.update(widget.user['id'], {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'extraInfo': _extraInfo.text.trim(),
        if (_isTeacher) 'approved': _approved,
      });
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit ${widget.user['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (_error != null) InfoBanner.error(_error!),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 10),
            TextField(controller: _extraInfo, decoration: InputDecoration(labelText: _isTeacher ? 'Qualification' : 'Extra info')),
            if (_isTeacher)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _approved,
                onChanged: (v) => setState(() => _approved = v ?? false),
                title: const Text('Approved teacher (can be listed and booked platform-wide)'),
              ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save changes')),
          ],
        ),
      ),
    );
  }
}

/// A teacher's resume plus every course application (status + intro video), for vetting.
class _TeacherDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;
  const _TeacherDetailsScreen({required this.teacher});

  @override
  State<_TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<_TeacherDetailsScreen> {
  List<dynamic>? _apps;
  String? _error;

  @override
  void initState() {
    super.initState();
    TeacherApi.applicationsForTeacher(widget.teacher['id']).then((a) {
      if (mounted) setState(() => _apps = a);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  void _open(String path) => launchUrl(Uri.parse(fileUrl(path)), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final t = widget.teacher;
    return Scaffold(
      appBar: AppBar(title: Text(t['name'] ?? 'Teacher')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${t['email']}${(t['phone'] ?? '').toString().isEmpty ? '' : ' · ${t['phone']}'}', style: const TextStyle(color: Colors.grey)),
          if ((t['extraInfo'] ?? '').toString().isNotEmpty) Text(t['extraInfo']),
          const SizedBox(height: 12),
          const SectionHeader('Resume'),
          if (t['resumeUrl'] != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _open(t['resumeUrl']),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Open resume'),
              ),
            )
          else
            const Text('No resume uploaded', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          const SectionHeader('Course applications'),
          if (_error != null) InfoBanner.error(_error!),
          if (_apps == null && _error == null) const LoadingView(),
          if (_apps != null && _apps!.isEmpty) const Text('No course applications yet.', style: TextStyle(color: Colors.grey)),
          ...?_apps?.map((a) => Card(
                child: ListTile(
                  title: Text(a['courseTitle'] ?? ''),
                  subtitle: a['introVideoUrl'] == null ? const Text('No intro video for this course') : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (a['introVideoUrl'] != null)
                      IconButton(
                        tooltip: 'Watch intro video',
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () => _open(a['introVideoUrl']),
                      ),
                    StatusPill(a['status'] ?? ''),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}
