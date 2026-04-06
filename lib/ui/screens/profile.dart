// lib/ui/profile/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/providers/auth_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/utils/avatar_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../routes/app_routes.dart';
import '../widgets/enterprise_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _emailUpdatesEnabled = true;

  // Theme selection
  late AppThemeMode _selectedThemeMode;

  // Stats data
  int _projectCount = 0;
  int _receiptCount = 0;
  int _taskCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _selectedThemeMode = themeProvider.appThemeMode;
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);

      // Get all projects count
      final projects = await db.getAllProjects();

      // Get all receipts count (expenses with images)
      int receiptCount = 0;
      for (final project in projects) {
        final expenses = await db.getExpensesByProject(project.id);
        receiptCount += expenses.where((e) => e.hasReceipt).length;
      }

      final taskCount = await db.countTasksForProjects(projects.map((p) => p.id).toList());

      if (mounted) {
        setState(() {
          _projectCount = projects.length;
          _receiptCount = receiptCount;
          _taskCount = taskCount;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _showInfoDialog({
    required String title,
    required String message,
    String buttonLabel = 'Close',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, bool isDark) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final email = emailController.text.trim();
                        if (name.isEmpty || email.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Name and email are required')),
                          );
                          return;
                        }
                        final ok = await auth.updateProfile(name: name, email: email);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (ok) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, bool isDark) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final oldP = oldController.text;
              final newP = newController.text;
              final confirm = confirmController.text;
              if (oldP.isEmpty || newP.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Fill all fields')),
                );
                return;
              }
              if (newP.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('New password must be at least 6 characters')),
                );
                return;
              }
              if (newP != confirm) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }
              final auth = Provider.of<AuthProvider>(ctx, listen: false);
              final ok = await auth.changePassword(oldPassword: oldP, newPassword: newP);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Password updated' : auth.errorMessage ?? 'Failed to update password'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final user = auth.currentUser;
    final displayName = user?.name ?? 'User';
    final displayEmail = user?.email ?? '—';

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: EnterpriseUi.appBarBg(isDark),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              onPressed: () => context.go(AppRoutes.home),
            ),
            title: Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            centerTitle: true,
          ),

          // Profile Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(EnterpriseUi.padH, 12, EnterpriseUi.padH, 8),
              child: _buildProfileHeader(isDark, displayName, displayEmail, user?.avatarUrl),
            ),
          ),

          // Stats Section
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: EnterpriseUi.padH),
            sliver: SliverToBoxAdapter(
              child: _isLoadingStats
                  ? const Center(child: CircularProgressIndicator())
                  : _buildStatsGrid(isDark),
            ),
          ),

          // Settings Sections
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EnterpriseUi.padH, 16, EnterpriseUi.padH, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Account Settings
                _buildSectionHeader(isDark, 'Account Settings'),
                const SizedBox(height: 8),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'Personal Information',
                  subtitle: 'Update your name and email',
                  onTap: () => _showEditProfileSheet(context, isDark),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.success,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () => _showChangePasswordDialog(context, isDark),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.email_outlined,
                  iconColor: AppColors.info,
                  title: 'Email Preferences',
                  subtitle: 'Manage email notifications',
                  onTap: () => context.push(AppRoutes.settings),
                ),

                const SizedBox(height: 24),

                // Preferences
                _buildSectionHeader(isDark, 'Preferences'),
                const SizedBox(height: 8),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.settings_rounded,
                  iconColor: AppColors.primary,
                  title: 'App Settings',
                  subtitle: 'Currency, notifications & more',
                  onTap: () => context.push(AppRoutes.settings),
                ),

                // Theme Dropdown
                _buildThemeDropdown(isDark, themeProvider),

                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.mark_email_read_outlined,
                  iconColor: AppColors.success,
                  title: 'Email Updates',
                  value: _emailUpdatesEnabled,
                  onChanged: (value) => setState(() => _emailUpdatesEnabled = value),
                ),

                const SizedBox(height: 24),

                // Support
                _buildSectionHeader(isDark, 'Support'),
                const SizedBox(height: 8),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.help_outline_rounded,
                  iconColor: AppColors.info,
                  title: 'Help Center',
                  subtitle: 'Get help with using the app',
                  onTap: () => _showInfoDialog(
                    title: 'Help Center',
                    message:
                        'Need help?\n\n1. Create or open a project.\n2. Add daily material entries or upload receipts.\n3. Use Reports for spending insights.\n4. Open Settings for backup, export, and security.',
                  ),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.description_outlined,
                  iconColor: AppColors.primary,
                  title: 'Terms of Service',
                  subtitle: 'Read our terms and conditions',
                  onTap: () => _showInfoDialog(
                    title: 'Terms of Service',
                    message:
                        'ProjectRack stores your data locally on device and can back it up to your connected Google account when enabled. You are responsible for the accuracy of project records and exported reports.',
                  ),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.privacy_tip_outlined,
                  iconColor: AppColors.secondary,
                  title: 'Privacy Policy',
                  subtitle: 'Learn how we handle your data',
                  onTap: () => _showInfoDialog(
                    title: 'Privacy Policy',
                    message:
                        'Project data stays on your device unless you choose Backup & Export actions. Biometric authentication only protects local app access on this device.',
                  ),
                ),

                const SizedBox(height: 24),

                // Sign Out Button
                _buildSignOutButton(isDark),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeDropdown(bool isDark, ThemeProvider themeProvider) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.brightness_6_rounded,
          color: AppColors.secondary,
          size: 20,
        ),
      ),
      title: Text(
        'Theme',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: Text(
        'Choose your preferred theme',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: DropdownButton<AppThemeMode>(
          value: _selectedThemeMode,
          underline: const SizedBox(),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            size: 20,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(
              value: AppThemeMode.light,
              child: Row(
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  const Text('Light'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AppThemeMode.dark,
              child: Row(
                children: [
                  Icon(
                    Icons.nights_stay_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Dark'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AppThemeMode.system,
              child: Row(
                children: [
                  Icon(
                    Icons.settings_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  const Text('System'),
                ],
              ),
            ),
          ],
          onChanged: (AppThemeMode? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedThemeMode = newValue;
              });
              themeProvider.setThemeMode(newValue);
            }
          },
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
  }

  void _showProfilePhotoOptions(BuildContext context, bool isDark) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSaveProfilePhoto(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSaveProfilePhoto(context, ImageSource.gallery);
              },
            ),
            if (auth.currentUser?.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeProfilePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeProfilePhoto() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.updateProfile(avatarUrl: null);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Profile photo removed' : 'Failed to remove photo'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndSaveProfilePhoto(BuildContext context, ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is needed to take a photo')),
          );
        }
        return;
      }
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (picked == null || !context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${dir.path}/profile_photos');
      if (!await profileDir.exists()) await profileDir.create(recursive: true);

      // Delete old photo if exists
      if (user.avatarUrl != null) {
        try {
          final oldFile = File(user.avatarUrl!);
          if (await oldFile.exists()) await oldFile.delete();
        } catch (_) {}
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${profileDir.path}/avatar_${user.id}_$timestamp.jpg';
      await File(picked.path).copy(path);

      if (!context.mounted) {
        if (mounted) Navigator.pop(context);
        return;
      }

      Navigator.pop(context); // Close loading

      final ok = await auth.updateProfile(avatarUrl: path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Profile photo updated' : 'Failed to update photo'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildProfileHeader(bool isDark, String displayName, String displayEmail, String? avatarUrl) {
    final imageProvider = avatarImageProvider(avatarUrl);
    final hasImage = imageProvider != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EnterpriseUi.cardDecoration(isDark),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showProfilePhotoOptions(context, isDark),
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasImage ? null : AppColors.primary.withOpacity(0.2),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage ? null : Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppColors.darkCard : Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Signed in',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () => _showEditProfileSheet(context, isDark),
            icon: Icon(
              Icons.edit_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    const accent = AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.projects),
              child: _buildStatCard(
                isDark: isDark,
                value: '$_projectCount',
                label: 'Projects',
                icon: Icons.folder_rounded,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.receiptGallery),
              child: _buildStatCard(
                isDark: isDark,
                value: '$_receiptCount',
                label: 'Receipts',
                icon: Icons.receipt_long_rounded,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.dailyLogsHistory),
              child: _buildStatCard(
                isDark: isDark,
                value: '$_taskCount',
                label: 'Tasks',
                icon: Icons.task_alt_rounded,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(EnterpriseUi.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title) {
    return EnterpriseUi.sectionLabel(title, isDark);
  }

  Widget _buildSettingsItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
      trailing: Icon(
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

  Widget _buildSignOutButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
        ),
      ),
      child: TextButton(
        onPressed: () {
          _showSignOutDialog(context);
        },
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              db.setActiveUserId(null);
              await auth.logout();
              if (!context.mounted) return;
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
}
