import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / Dark / Auto (follow system), persisted — mirrors the web's ThemeContext.jsx.
class ThemeState extends ChangeNotifier {
  static const _storageKey = 'stepup_theme';

  String _mode = 'auto'; // 'light' | 'dark' | 'auto'
  String get mode => _mode;

  ThemeMode get themeMode => switch (_mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_storageKey) ?? 'auto';
    notifyListeners();
  }

  Future<void> setMode(String mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode);
  }
}
