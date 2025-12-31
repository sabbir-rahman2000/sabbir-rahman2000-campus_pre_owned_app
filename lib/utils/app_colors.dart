import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF87CEEB); // Sky blue
  static const Color primaryLight = Color(0xFFB0E0E6); // Light blue
  static const Color primaryDark = Color(0xFF4A90A4); // Dark blue
  static const Color background = Color(0xFFF9FAFB); // Light gray
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color border = Color(0xFFE2E8F0);
  
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient get splashGradient => const LinearGradient(
    colors: [primary, Color(0xFF5DADE2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}