import 'package:flutter/material.dart';
import '../theme/dark_theme.dart' as dt;

class ThemeProvider extends ChangeNotifier {
  // Always dark mode
  bool get isDark => true;

  ThemeProvider();

  Future<void> toggle() async {
    // No-op: only dark mode allowed
    notifyListeners();
  }

  ThemeData get dark => dt.darkTheme;
}
