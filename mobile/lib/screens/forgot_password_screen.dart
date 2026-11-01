import 'package:flutter/material.dart';
import '../api/endpoints.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/theme_toggle.dart';

/// TEMPORARY: no identity verification (no OTP / email link) — matches the backend's
/// AuthService.resetPassword placeholder. Mirrors the web's ForgotPassword.jsx.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => _error = "New password and confirm password don't match.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthApi.forgotPassword(_email.text.trim(), _newPassword.text, _confirmPassword.text);
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: kBrandGradient),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(top: 8, right: 16, child: ThemeToggle()),
              Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png', height: 56),
                      const SizedBox(height: 14),
                      const Text('Reset your password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const Text('Enter your account email and a new password.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      if (_error != null) InfoBanner.error(_error!),
                      if (_done) ...[
                        InfoBanner.info('Password reset. You can log in with your new password now.'),
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to login')),
                      ] else
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'Email'),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _newPassword,
                                decoration: const InputDecoration(labelText: 'New password'),
                                obscureText: true,
                                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPassword,
                                decoration: const InputDecoration(labelText: 'Confirm new password'),
                                obscureText: true,
                                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Resetting...' : 'Reset password')),
                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to login')),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
