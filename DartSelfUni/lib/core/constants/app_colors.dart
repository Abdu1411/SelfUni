import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB); // blue-600
  static const Color primaryLight = Color(0xFF3B82F6); // blue-500
  static const Color primaryDark = Color(0xFF1D4ED8); // blue-700
  
  // Dark Glassmorphism Theme System
  static const Color background = Color(0xFF0B132B); // Deep navy/slate background
  static const Color darkBackground = Color(0xFF0B132B);
  static const Color darkSurface = Color(0xFF162238); // Glass container surface
  static const Color surface = Color(0xFF162238);
  static const Color border = Color(0xFF2A3B5C); // Subtle glass border
  
  static const Color textPrimary = Color(0xFFF8FAFC); // Bright white-slate
  static const Color textSecondary = Color(0xFF94A3B8); // Muted slate text
  
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFF43F5E); // rose-500
  static const Color accentCyan = Color(0xFF00B4D8);
  static const Color accentPurple = Color(0xFFA855F7);
  
  // Glowing Hero Gradient
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [Color(0x221E293B), Color(0x110F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
    'Concept': Color(0x22F59E0B), // amber glass
    'Complexity': Color(0x22A855F7), // purple glass
    'Pattern': Color(0x223B82F6), // blue glass
    'Cloze': Color(0x2210B981), // emerald glass
    'Comparison': Color(0x226366F1), // indigo glass
    'Trace': Color(0x2206B6D4), // cyan glass
    'Invariant': Color(0x2214B8A6), // teal glass
    'Debugging': Color(0x22F43F5E), // rose glass
    'Implementation': Color(0x220EA5E9), // sky glass
  };
}
