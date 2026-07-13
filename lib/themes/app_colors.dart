import 'package:flutter/material.dart';

class AppColors {

  // =========================================================
  // BRAND COLORS - Modern Industrial Violet Identity
  // =========================================================

  static const Color primary = Color(0xFF5E4EE3);      // Slightly warmer violet
  static const Color primaryLight = Color(0xFF7B6EF6);
  static const Color primaryDark = Color(0xFF4338B5);
  static const Color primarySubtle = Color(0xFFF1EFFF);

  // Accent - Used for active states, selected items
  static const Color accent = Color(0xFF8B7CF6);

  // =========================================================
  // SEMANTIC COLORS
  // =========================================================

  static const Color success = Color(0xFF2F855A);
  static const Color warning = Color(0xFFD69E2E);
  static const Color error = Color(0xFFC53030);
  static const Color info = Color(0xFF2B6CB0);

  // =========================================================
  // LIGHT THEME
  // =========================================================

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF334155);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // =========================================================
  // DARK THEME
  // =========================================================

  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkBorder = Color(0xFF334155);

  // =========================================================
  // PROJECT CATEGORY COLORS
  // =========================================================

  static const Color construction = Color(0xFFC97316);   // Orange - Durability
  static const Color agriculture = Color(0xFF2F855A);    // Green - Growth
  static const Color retail = Color(0xFFD69E2E);         // Amber - Commerce
  static const Color personal = Color(0xFF4A5568);       // Slate - Neutral
  static const Color design = Color(0xFFB83280);         // Magenta - Creativity
  static const Color development = Color(0xFF5E4EE3);    // Violet - Technical

  // =========================================================
  // CHART COLORS
  // =========================================================

  static const List<Color> chartColors = [
    Color(0xFF5E4EE3), // Primary violet
    Color(0xFFC97316), // Construction orange
    Color(0xFF2F855A), // Agriculture green
    Color(0xFFD69E2E), // Amber
    Color(0xFF2B6CB0), // Blue
    Color(0xFFB83280), // Magenta
    Color(0xFFC53030), // Red
    Color(0xFF4A5568), // Slate
  ];

  // =========================================================
  // BUTTONS / FAB
  // =========================================================

  static const Color fabBackground = primary;
  static const Color fabForeground = Colors.white;

  // =========================================================
  // GRADIENTS
  // =========================================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5E4EE3), Color(0xFF7B6EF6)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F855A), Color(0xFF48BB78)],
  );

  static const LinearGradient constructionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC97316), Color(0xFFED8936)],
  );

  // =========================================================
  // BACKWARDS COMPATIBILITY LAYER
  // =========================================================
  // These variables map to the new Modern Industrial Violet
  // Identity palette, preventing compilation errors and
  // propagating the new styling safely across all legacy code.

  static const Color primaryMuted = Color(0xFF8B7CF6);  // Harmonies with primary violet accent

  static const Color secondary = accent;
  static const Color secondaryLight = Color(0xFFA599FF);
  static const Color secondaryDark = Color(0xFF7465E6);

  static const Color successLight = Color(0xFF48BB78);
  static const Color successDark = Color(0xFF22543D);

  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color errorLight = Color(0xFFFEB2B2);
  static const Color errorDark = Color(0xFF9B2C2C);

  static const Color infoLight = Color(0xFF63B3ED);
  static const Color infoDark = Color(0xFF2C5282);

  static const Color lightTextTertiary = Color(0xFF64748B);
  static const Color lightDivider = lightBorder;

  static const Color darkCardElevated = Color(0xFF243049);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkDivider = Color(0xFF1E293B);

  static const Color convexBackground = primary;
  static const Color convexGlow = primaryLight;
  static const Color convexText = Colors.white;

  static const Color salamonoBackground = lightBackground;
  static const Color salamonoCard = lightCard;
  static const Color salamonoShadow = Color(0x0A000000);      // Extremely subtle card shadow
  static const Color salamonoShadowDark = Color(0x2A000000);  // Subtle dark mode card shadow

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );

  static const LinearGradient convexGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryDark],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [error, Color(0xFFFC8181)],
  );
}