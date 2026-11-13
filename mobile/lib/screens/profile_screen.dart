import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';

const _extraLabel = {
  'STUDENT': 'Grade / education level',
  'TEACHER': 'Qualification & experience',
  'COORDINATOR': 'About you',
  'ADMIN': 'About you',
};

/// Every user edits their own name, email, phone, short bio and (optionally) password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _extra;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthState>().user ?? {};
    _name = TextEditingController(text: u['name'] ?? '');
    _email = TextEditingController(text: u['email'] ?? '');
    _phone = TextEditingController(text: u['phone'] ?? '');
    _extra = TextEditingController(text: u['extraInfo'] ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final changingPassword = _current.text.isNotEmpty || _next.text.isNotEmpty || _confirm.text.isNotEmpty;
    if (changingPassword) {
      if (_current.text.isEmpty) return setState(() => _error = 'Enter your current password to set a new one.');
      if (_next.text.length < 6) return setState(() => _error = 'New password must be at least 6 characters.');
      if (_next.text != _confirm.text) return setState(() => _error = "New password and confirmation don't match.");
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'extraInfo': _extra.text.trim().isEmpty ? null : _extra.text.trim(),
        'currentPassword': changingPassword ? _current.text : null,
        'newPassword': changingPassword ? _next.text : null,
      });
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(changingPassword ? 'Profile and password updated' : 'Profile updated')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user ?? {};
    final role = (user['role'] ?? '') as String;
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(child: UserAvatar(user['name'], size: 84)),
              const SizedBox(height: 10),
              Center(child: Text(user['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              Center(child: RolePill(role)),
              const SizedBox(height: 20),
              if (_error != null) InfoBanner.error(_error!),
              const SectionHeader('Edit profile'),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline, size: 20)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extra,
                maxLines: 2,
                decoration: InputDecoration(labelText: _extraLabel[role] ?? 'About you', prefixIcon: const Icon(Icons.info_outline, size: 20)),
              ),
              const SizedBox(height: 24),
              const SectionHeader('Change password'),
              const Text('Leave blank to keep your current password.', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
              const SizedBox(height: 10),
              PasswordField(controller: _current, label: 'Current password'),
              const SizedBox(height: 12),
              PasswordField(controller: _next, label: 'New password'),
              const SizedBox(height: 12),
              PasswordField(controller: _confirm, label: 'Confirm new password'),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving...' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
