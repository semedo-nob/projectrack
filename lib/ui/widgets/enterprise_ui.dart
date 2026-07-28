import 'package:flutter/material.dart';
import 'package:projectrack1/themes/app_colors.dart';

/// Shared layout and decoration for list-heavy, production screens.
abstract final class EnterpriseUi {
  static const double padH = 16;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static Color screenBg(bool isDark) =>
      isDark ? AppColors.darkBackground : AppColors.lightBackground;

  static Color appBarBg(bool isDark) =>
      isDark ? AppColors.darkSurface : Colors.white;

  /// Small uppercase section label (matches dashboard-style hierarchy).
  static Widget sectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
      ),
    );
  }

  static BoxDecoration cardDecoration(bool isDark, {bool selected = false}) {
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: selected ? 2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: (isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow)
              .withOpacity(0.45),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Flat card: border only, minimal shadow (settings-style groups).
  static BoxDecoration groupedListDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    );
  }

  /// Circular primary FAB — matches receipt gallery; avoids extended FABs
  /// which clash with the app's CircleBorder FAB theme.
  static Widget primaryFab({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
  }) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: Icon(icon, size: 26),
    );
  }
}
