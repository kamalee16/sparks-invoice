import 'package:flutter/material.dart';
import 'app_colors.dart';

final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.darkSurface,
    onPrimary: Colors.white,
    onSurface: Colors.white,
    surfaceContainer: AppColors.darkCard,
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    ),
    iconTheme: IconThemeData(color: Colors.white, size: 24),
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide.none,
    ),
    margin: EdgeInsets.zero,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      shadowColor: AppColors.primary.withOpacity(0.4),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: const BorderSide(color: AppColors.primary, width: 2),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkInput,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.danger)),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle: const TextStyle(color: AppColors.textMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  ),
  dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.05), thickness: 1),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkCard,
    selectedColor: AppColors.primary.withOpacity(0.2),
    labelStyle: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide.none,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey.shade600),
    trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade800),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
    displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
    displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
    headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
    titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
    bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
    bodyMedium: const TextStyle(color: Colors.white70, fontSize: 14),
    bodySmall: const TextStyle(color: Colors.white54, fontSize: 12),
  ),
);
