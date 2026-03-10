import 'package:flutter/material.dart';

class AppColors {
  // ===== PRIMARY COLORS - Rich Violet Palette =====
  // These are your brand colors - all violets with good contrast
  static const Color primary = Color(0xFF5A4FCF);      // Slightly deeper for better contrast
  static const Color primaryLight = Color(0xFF7C6FF2);  // Brighter, good for highlights
  static const Color primaryDark = Color(0xFF3F36A0);   // Deeper for dark mode accents
  static const Color primaryMuted = Color(0xFF8A7FDC);  // Muted for backgrounds
  static const Color primarySubtle = Color(0xFFF0EEFF); // Very light for backgrounds

  // ===== SECONDARY COLORS - Accent Violet (removed coral pink) =====
  static const Color secondary = Color(0xFF9D8FF5);     // Lighter violet for variety
  static const Color secondaryLight = Color(0xFFB1A5FF); // Very light violet
  static const Color secondaryDark = Color(0xFF6B5FD9);  // Medium violet

  // ===== SEMANTIC COLORS =====
  static const Color success = Color(0xFF2E9A6A);       // Deeper green for contrast
  static const Color successLight = Color(0xFF4ADE80);
  static const Color successDark = Color(0xFF1E7B4C);

  static const Color warning = Color(0xFFF59E0B);       // Amber (not yellow)
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFE53E3E);         // Deeper red for contrast
  static const Color errorLight = Color(0xFFFC8181);
  static const Color errorDark = Color(0xFFC53030);

  static const Color info = Color(0xFF3182CE);          // Deeper blue
  static const Color infoLight = Color(0xFF63B3ED);
  static const Color infoDark = Color(0xFF2C5282);

  // ===== NEUTRAL COLORS - Light Mode (Improved contrast) =====
  static const Color lightBackground = Color(0xFFFFFFFF);      // Pure white
  static const Color lightSurface = Color(0xFFF8FAFC);         // Slightly off-white
  static const Color lightCard = Color(0xFFFFFFFF);            // White cards
  static const Color lightText = Color(0xFF0F172A);            // Almost black - 16:1 contrast
  static const Color lightTextSecondary = Color(0xFF334155);   // Dark gray - 12:1 contrast
  static const Color lightTextTertiary = Color(0xFF475569);    // Medium gray - 8:1 contrast
  static const Color lightBorder = Color(0xFFE2E8F0);          // Light border
  static const Color lightDivider = Color(0xFFCBD5E1);         // Slightly darker divider

  // ===== NEUTRAL COLORS - Dark Mode (Improved readability) =====
  static const Color darkBackground = Color(0xFF0A0C1A);       // Deep navy
  static const Color darkSurface = Color(0xFF1A1D2E);          // Slightly lighter
  static const Color darkCard = Color(0xFF252837);             // Card background
  static const Color darkCardElevated = Color(0xFF2D3042);     // Elevated cards
  static const Color darkText = Color(0xFFF8FAFC);             // Almost white - 18:1 contrast
  static const Color darkTextSecondary = Color(0xFFCBD5E1);    // Light gray - 15:1 contrast
  static const Color darkTextTertiary = Color(0xFF94A3B8);     // Medium gray - 12:1 contrast
  static const Color darkBorder = Color(0xFF2D2F42);           // Border color
  static const Color darkDivider = Color(0xFF343949);          // Divider color

  // ===== CATEGORY COLORS (All violet-based for consistency) =====
  static const Color construction = Color(0xFF5A4FCF);         // Primary violet
  static const Color agriculture = Color(0xFF7C6FF2);          // Light violet
  static const Color retail = Color(0xFF9D8FF5);               // Lighter violet
  static const Color personal = Color(0xFFB1A5FF);             // Very light violet
  static const Color design = Color(0xFF3F36A0);               // Dark violet
  static const Color development = Color(0xFF6B5FD9);          // Medium violet

  // ===== CHART COLORS (Violet family + semantic) =====
  static const List<Color> chartColors = [
    Color(0xFF5A4FCF),  // Primary
    Color(0xFF7C6FF2),  // Light primary
    Color(0xFF9D8FF5),  // Lighter
    Color(0xFF3F36A0),  // Dark primary
    Color(0xFF6B5FD9),  // Medium
    Color(0xFF2E9A6A),  // Success (green)
    Color(0xFFF59E0B),  // Warning (amber)
    Color(0xFFE53E3E),  // Error (red)
    Color(0xFF3182CE),  // Info (blue)
  ];

  // ===== CONVEX BUTTON COLORS =====
  static const Color convexBackground = Color(0xFF5A4FCF);     // Primary
  static const Color convexGlow = Color(0xFF8F7EFF);           // Primary light
  static const Color convexText = Colors.white;

  // ===== SALAMONO STYLE COLORS (Clean, minimal) =====
  static const Color salamonoBackground = Color(0xFFF8FAFC);
  static const Color salamonoCard = Color(0xFFFFFFFF);
  static const Color salamonoShadow = Color(0x1A000000);
  static const Color salamonoShadowDark = Color(0x4D000000);

  // ===== GRADIENTS =====
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A4FCF), Color(0xFF7C6FF2)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9D8FF5), Color(0xFFB1A5FF)],
  );

  static const LinearGradient convexGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A4FCF), Color(0xFF3F36A0)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E9A6A), Color(0xFF4ADE80)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE53E3E), Color(0xFFFC8181)],
  );
}