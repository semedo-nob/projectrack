// theme_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_theme.dart';

const String _prefThemeMode = 'app_theme_mode';


enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeMode _appThemeMode = AppThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  AppThemeMode get appThemeMode => _appThemeMode;

  ThemeProvider() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefThemeMode);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
        _appThemeMode = AppThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
        _appThemeMode = AppThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
        _appThemeMode = AppThemeMode.system;
      }
    } catch (_) {
      _themeMode = ThemeMode.system;
      _appThemeMode = AppThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _appThemeMode = mode;
    switch (mode) {
      case AppThemeMode.light:
        _themeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        _themeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        _themeMode = ThemeMode.system;
        break;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeMode, mode == AppThemeMode.light ? 'light' : mode == AppThemeMode.dark ? 'dark' : 'system');
    } catch (_) {}
    notifyListeners();
  }

  // Toggle between light and dark (ignores system)
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(AppThemeMode.dark);
    } else {
      setThemeMode(AppThemeMode.light);
    }
  }

  // Check if current mode is dark
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // Get current theme data based on context
  ThemeData getTheme(BuildContext context) {
    final isDark = isDarkMode(context);
    return isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }
}

// Extension for easy access in widgets
extension ThemeProviderExtension on BuildContext {
  ThemeProvider get themeProvider => Provider.of<ThemeProvider>(this, listen: false);
  bool get isDarkMode => Provider.of<ThemeProvider>(this, listen: true).isDarkMode(this);
}

// Theme Provider Widget
class ThemeProviderWidget extends StatelessWidget {
  final Widget child;

  const ThemeProviderWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.themeMode,
            home: child,
          );
        },
      ),
    );
  }
}