import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';

// Coordinator and Admin accounts are created by an admin (see admin Users screen) — not self-signup.
const Map<String, String> _extraLabel = {
  'STUDENT': 'Grade / education level (e.g. Grade 10)',
  'TEACHER': 'Qualification & experience (e.g. M.Sc Mathematics, 5 yrs experience)',
};

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _extraInfo = TextEditingController();
  String _role = 'STUDENT';
  String? _resumePath;
  String? _resumeName;
  bool _busy = false;
  String? _error;

  Future<void> _pickResume() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    final f = res?.files.single;
    if (f?.path != null) {
      setState(() {
        _resumePath = f!.path;
        _resumeName = f.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().signup({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'phone': _phone.text.trim(),
        'role': _role,
        'extraInfo': _extraInfo.text.trim(),
      }, resumePath: _role == 'TEACHER' ? _resumePath : null);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) InfoBanner.error(_error!),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'I am a'),
                items: const [
                  DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                  DropdownMenuItem(value: 'TEACHER', child: Text('Teacher')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'STUDENT'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extraInfo,
                decoration: InputDecoration(labelText: _extraLabel[_role]),
              ),
              if (_role == 'TEACHER') ...[
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(_resumeName ?? 'Attach resume (optional)', style: TextStyle(color: _resumeName == null ? Colors.grey : null)),
                  onTap: _pickResume,
                ),
                const Text(
                  'Teacher accounts need Admin approval before you can be listed and apply to courses. '
                  'You can log in right away and track your status. You can attach your resume now or skip it for later.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Creating account...' : 'Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
