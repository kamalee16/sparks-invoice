import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/light_theme.dart' as lt;
import '../theme/dark_theme.dart' as dt;

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDarkMode';
  bool _isDark = true;

  bool get isDark => _isDark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
    notifyListeners();
  }

  ThemeData get light => lt.lightTheme;
  ThemeData get dark => dt.darkTheme;
}
