import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _themePrefKey = 'user_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themePrefKey);
      if (savedMode == 'dark') {
        state = ThemeMode.dark;
      } else if (savedMode == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themePrefKey,
        mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'),
      );
    } catch (_) {}
  }
}
