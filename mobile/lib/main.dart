import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/auth_state.dart';
import 'state/theme_state.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/root_shell.dart';

void main() {
  runApp(const StepUpHubApp());
}

class StepUpHubApp extends StatelessWidget {
  const StepUpHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ThemeState()..load()),
      ],
      child: Builder(
        builder: (context) {
          final themeState = context.watch<ThemeState>();
          return MaterialApp(
            title: 'StepUp Hub',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(brightness: Brightness.light),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            themeMode: themeState.themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.user == null ? const LoginScreen() : const RootShell();
  }
}
