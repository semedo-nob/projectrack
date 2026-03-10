// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App Settings
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _darkMode = false;
  bool _autoSync = true;
  bool _biometricAuth = false;
  bool _dataSaver = false;

  // App Preferences
  String _selectedLanguage = 'English';
  String _selectedDateFormat = 'MM/DD/YYYY';
  String _selectedTheme = 'System Default';

  final List<String> _languages = ['English', 'Spanish', 'French', 'German', 'Japanese'];
  final List<String> _dateFormats = ['MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY/MM/DD'];
  final List<String> _themes = ['Light', 'Dark', 'System Default'];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Settings'),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                  ),
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go(AppRoutes.home),
                color: Colors.white,
              ),
            ),
          ),

          // Settings Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Account Section
                _buildSectionHeader(isDark, 'Account'),
                const SizedBox(height: 8),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'Profile Information',
                  subtitle: 'Update your personal details',
                  onTap: () => context.push(AppRoutes.profile),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.success,
                  title: 'Security',
                  subtitle: 'Password and authentication',
                  onTap: () {},
                  trailing: _buildBadge('2FA', isDark),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.email_outlined,
                  iconColor: AppColors.info,
                  title: 'Email Preferences',
                  subtitle: 'Manage email communications',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // Notifications Section
                _buildSectionHeader(isDark, 'Notifications'),
                const SizedBox(height: 8),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.warning,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications',
                  value: _pushNotifications,
                  onChanged: (value) => setState(() => _pushNotifications = value),
                ),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.mark_email_read_rounded,
                  iconColor: AppColors.primary,
                  title: 'Email Notifications',
                  subtitle: 'Receive email updates',
                  value: _emailNotifications,
                  onChanged: (value) => setState(() => _emailNotifications = value),
                ),

                const SizedBox(height: 24),

                // Appearance Section
                _buildSectionHeader(isDark, 'Appearance'),
                const SizedBox(height: 8),
                _buildDropdownItem(
                  isDark: isDark,
                  icon: Icons.language_rounded,
                  iconColor: AppColors.secondary,
                  title: 'Language',
                  value: _selectedLanguage,
                  items: _languages,
                  onChanged: (value) => setState(() => _selectedLanguage = value!),
                ),
                _buildDropdownItem(
                  isDark: isDark,
                  icon: Icons.palette_rounded,
                  iconColor: AppColors.primary,
                  title: 'Theme',
                  value: _selectedTheme,
                  items: _themes,
                  onChanged: (value) {
                    setState(() => _selectedTheme = value!);
                    if (value == 'Light') {
                      themeProvider.setThemeMode(AppThemeMode.light);
                    } else if (value == 'Dark') {
                      themeProvider.setThemeMode(AppThemeMode.dark);
                    } else {
                      themeProvider.setThemeMode(AppThemeMode.system);
                    }
                  },
                ),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.dark_mode_rounded,
                  iconColor: AppColors.secondaryLight,
                  title: 'Dark Mode',
                  subtitle: 'Toggle dark theme',
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    themeProvider.toggleTheme();
                  },
                ),

                const SizedBox(height: 24),

                // Preferences Section
                _buildSectionHeader(isDark, 'Preferences'),
                const SizedBox(height: 8),
                _buildCurrencyItem(isDark: isDark),
                _buildDropdownItem(
                  isDark: isDark,
                  icon: Icons.calendar_today_rounded,
                  iconColor: AppColors.warning,
                  title: 'Date Format',
                  value: _selectedDateFormat,
                  items: _dateFormats,
                  onChanged: (value) => setState(() => _selectedDateFormat = value!),
                ),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.sync_rounded,
                  iconColor: AppColors.info,
                  title: 'Auto-sync',
                  subtitle: 'Automatically sync data',
                  value: _autoSync,
                  onChanged: (value) => setState(() => _autoSync = value),
                ),

                const SizedBox(height: 24),

                // Privacy & Security Section
                _buildSectionHeader(isDark, 'Privacy & Security'),
                const SizedBox(height: 8),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.fingerprint_rounded,
                  iconColor: AppColors.primary,
                  title: 'Biometric Authentication',
                  subtitle: 'Use fingerprint or face ID',
                  value: _biometricAuth,
                  onChanged: (value) => setState(() => _biometricAuth = value),
                ),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.data_saver_on_rounded,
                  iconColor: AppColors.success,
                  title: 'Data Saver',
                  subtitle: 'Reduce data usage',
                  value: _dataSaver,
                  onChanged: (value) => setState(() => _dataSaver = value),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.privacy_tip_rounded,
                  iconColor: AppColors.info,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  onTap: () {},
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.security_rounded,
                  iconColor: AppColors.warning,
                  title: 'Security Recommendations',
                  subtitle: 'Tips to secure your account',
                  onTap: () {},
                  trailing: _buildBadge('3 tips', isDark, color: AppColors.warning),
                ),

                const SizedBox(height: 24),

                // Storage & Data Section
                _buildSectionHeader(isDark, 'Storage & Data'),
                const SizedBox(height: 8),
                _buildStorageInfo(isDark),
                const SizedBox(height: 12),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.storage_rounded,
                  iconColor: AppColors.secondary,
                  title: 'Manage Storage',
                  subtitle: 'Clear cache and data',
                  onTap: () => _showClearCacheDialog(context),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.backup_rounded,
                  iconColor: AppColors.primary,
                  title: 'Backup & Restore',
                  subtitle: 'Backup your data to cloud',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader(isDark, 'About'),
                const SizedBox(height: 8),
                _buildAboutItem(isDark),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.star_outline_rounded,
                  iconColor: AppColors.warning,
                  title: 'Rate the App',
                  subtitle: 'Leave a review on the store',
                  onTap: () {},
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.share_rounded,
                  iconColor: AppColors.success,
                  title: 'Share App',
                  subtitle: 'Tell your friends about us',
                  onTap: () {},
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.bug_report_rounded,
                  iconColor: AppColors.error,
                  title: 'Report a Bug',
                  subtitle: 'Help us improve the app',
                  onTap: () {},
                ),

                const SizedBox(height: 32),

                // Sign Out Button
                _buildSignOutButton(isDark),

                const SizedBox(height: 32),

                // App Version
                Center(
                  child: Text(
                    'Version 2.4.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
  }

  Widget _buildSwitchItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        activeTrackColor: AppColors.primaryLight,
        inactiveThumbColor: isDark ? AppColors.darkTextTertiary : Colors.grey,
        inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
  }

  Widget _buildCurrencyItem({required bool isDark}) {
    return Consumer<CurrencyProvider>(
      builder: (context, currency, _) {
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.attach_money_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
          title: Text(
            'Currency',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          subtitle: Text(
            currency.displayLabel,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          onTap: () async {
            final chosen = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Select currency',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ),
                      ...CurrencyProvider.options.map((opt) => ListTile(
                        title: Text(opt.label),
                        selected: currency.currencyCode == opt.code,
                        onTap: () => Navigator.pop(ctx, opt.code),
                      )),
                    ],
                  ),
                ),
              ),
            );
            if (chosen != null) await currency.setCurrency(chosen);
          },
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        );
      },
    );
  }

  Widget _buildDropdownItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: DropdownButton<String>(
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
        dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
        isExpanded: false,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
  }

  Widget _buildStorageInfo(bool isDark) {
    final usedStorage = 2.4; // GB
    final totalStorage = 8.0; // GB
    final percentage = usedStorage / totalStorage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Usage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${usedStorage.toStringAsFixed(1)} GB of $totalStorage GB used',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutItem(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'PR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ProjectRack',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 2.4.0 (Build 2401)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '© 2024 ProjectRack Inc.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color ?? AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSignOutButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
        ),
      ),
      child: TextButton(
        onPressed: () => _showSignOutDialog(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. You will need to download some content again. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cache cleared successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}