import 'package:flutter/material.dart';

class AppColors {
  // Brand — Premium Dark Theme
  static const darkBg      = Color(0xFF111318); // Page background
  static const darkSurface = Color(0xFF232326); // Card surface
  static const darkCard    = Color(0xFF232326); // Card background
  static const darkInput   = Color(0xFF1A1A1E); // Input field background

  // Accent Colors (Status Based)
  static const success = Color(0xFF00E5A8); // Revenue (Green)
  static const warning = Color(0xFFFFA726); // Unpaid (Orange)
  static const danger  = Color(0xFFFF5252); // Overdue (Red)
  static const neutral = Color(0xFF7C83FD); // Neutral (Purple/Blue)
  static const info    = Color(0xFF7C83FD);
  static const primary = Color(0xFF00E5A8);
  static const secondary = Color(0xFF7C83FD);

  // Glass Gradients Helper
  static LinearGradient glassGradient(Color color) => LinearGradient(
    colors: [
      color.withOpacity(0.25),
      color.withOpacity(0.10),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Premium Gradients
  static final heroGradient = glassGradient(success);
  static final paidGradient = glassGradient(success);
  static final unpaidGradient = glassGradient(warning);
  static final overdueGradient = glassGradient(danger);
  static final countGradient = glassGradient(neutral);
  static final outstandingGradient = glassGradient(neutral);

  // Text Colors
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA0A0A0);
  static const textMuted     = Color(0xFF707070);

  // Soft Glow Helper
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.25),
      blurRadius: 20,
      spreadRadius: 1,
    ),
  ];

  // Remove borders completely
  static const darkCardBorder = Colors.transparent;
}
