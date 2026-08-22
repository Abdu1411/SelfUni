import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB); // blue-600
  static const Color primaryLight = Color(0xFF3B82F6); // blue-500
  static const Color primaryDark = Color(0xFF1D4ED8); // blue-700
  
  static const Color background = Color(0xFFF8FAFC); // slate-50
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0); // slate-200
  
  static const Color textPrimary = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFEF4444); // red-500
  
  // Archetype colors
  static const Map<String, Color> archetypeColors = {
    'Concept': Color(0xFFF59E0B), // amber
    'Complexity': Color(0xFFA855F7), // purple
    'Pattern': Color(0xFF3B82F6), // blue
    'Cloze': Color(0xFF10B981), // emerald
    'Comparison': Color(0xFF6366F1), // indigo
    'Trace': Color(0xFF06B6D4), // cyan
    'Invariant': Color(0xFF14B8A6), // teal
    'Debugging': Color(0xFFF43F5E), // rose
    'Implementation': Color(0xFF0EA5E9), // sky
  };
  
  static const Map<String, Color> archetypeBgs = {
    'Concept': Color(0xFFFFFBEB), // amber-50
    'Complexity': Color(0xFFFAF5FF), // purple-50
    'Pattern': Color(0xFFEFF6FF), // blue-50
    'Cloze': Color(0xFFECFDF5), // emerald-50
    'Comparison': Color(0xFFEEF2FF), // indigo-50
    'Trace': Color(0xFFECFEFF), // cyan-50
    'Invariant': Color(0xFFF0FDFA), // teal-50
    'Debugging': Color(0xFFFFF1F2), // rose-50
    'Implementation': Color(0xFFF0F9FF), // sky-50
  };
}
