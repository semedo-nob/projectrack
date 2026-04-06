// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../service/backup_service.dart';
import '../../service/export_service.dart';
import '../../service/google_sync_service.dart';
import '../widgets/enterprise_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _biometricAuth = false;
  bool _dataSaver = false;
  bool _autoSyncEnabled = false;
  bool _isSyncing = false;
  String? _googleAccountEmail;
  DateTime? _lastSyncAt;
  bool _backupBusy = false;
  bool _restoreBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettingsState());
  }

  Future<void> _loadSettingsState() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sync = GoogleSyncService.instance;
    final linkedEmail = await sync.getLinkedAccountEmail();
    final lastSync = await sync.getLastSyncAt();
    final autoSync = await sync.isAutoSyncEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAuth = auth.biometricEnabled;
      _googleAccountEmail = linkedEmail;
      _lastSyncAt = lastSync;
      _autoSyncEnabled = autoSync;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode(context);
    _biometricAuth = auth.biometricEnabled;

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
              onPressed: () => context.go(AppRoutes.profile),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),

          // Settings Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EnterpriseUi.padH, 8, EnterpriseUi.padH, 24),
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
                  onTap: () => _showSnackBar(
                    'Use the biometric toggle below for app lock. Password change lives under your account profile.',
                    AppColors.info,
                  ),
                  trailing: _buildBadge(
                    _biometricAuth ? 'Locked' : 'Standard',
                    isDark,
                  ),
                ),

                // (Email Preferences moved out as requested)
                const SizedBox(height: 24),

                // Backup & Export
                _buildSectionHeader(isDark, 'Backup & Export'),
                const SizedBox(height: 8),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.backup_table_rounded,
                  iconColor: AppColors.info,
                  title: 'Backup & Export Center',
                  subtitle: _googleSyncSubtitle(),
                  onTap: () => _showGoogleSyncSheet(isDark),
                  trailing: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _buildBadge(
                          _googleAccountEmail == null ? 'Offline' : 'Connected',
                          isDark,
                          color: _googleAccountEmail == null
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.file_download_outlined,
                  iconColor: AppColors.secondary,
                  title: 'Export local backup',
                  subtitle: 'Save projects, expenses, and receipts as JSON',
                  onTap: () {
                    if (!_backupBusy) _exportLocalBackup(context);
                  },
                  trailing: _backupBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.restore_page_outlined,
                  iconColor: AppColors.warning,
                  title: 'Restore from backup',
                  subtitle: 'Replace all data from a JSON backup file',
                  onTap: () {
                    if (!_restoreBusy) _restoreFromBackup(context);
                  },
                  trailing: _restoreBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),

                const SizedBox(height: 24),

                // Preferences
                _buildSectionHeader(isDark, 'Preferences'),
                const SizedBox(height: 8),
                _buildCurrencyItem(isDark: isDark),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.straighten_rounded,
                  iconColor: AppColors.primary,
                  title: 'Units & smart suggestions',
                  subtitle: 'Defaults, cement/sand hints, and learning',
                  onTap: () => context.push(AppRoutes.unitSettings),
                ),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.warning,
                  title: 'Push Notifications',
                  subtitle: 'Budget alerts and reminders',
                  value: _pushNotifications,
                  onChanged: (value) =>
                      setState(() => _pushNotifications = value),
                ),
                _buildSwitchItem(
                  isDark: isDark,
                  icon: Icons.mark_email_read_rounded,
                  iconColor: AppColors.primary,
                  title: 'Email Updates',
                  subtitle: 'Receipts, reports, and sync notices',
                  value: _emailNotifications,
                  onChanged: (value) =>
                      setState(() => _emailNotifications = value),
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
                  onChanged: _handleBiometricToggle,
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
                const SizedBox(height: 24),

                // Support & Legal
                _buildSectionHeader(isDark, 'Support & Legal'),
                const SizedBox(height: 8),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.help_outline_rounded,
                  iconColor: AppColors.info,
                  title: 'Help Center',
                  subtitle: 'How backup, exports, and security work',
                  onTap: () => _showInfoDialog(
                    title: 'Help Center',
                    message:
                        'Use Backup & Export Center to connect Google Drive, upload a backup, restore data on a new device, or export project files.\n\nTurn on Biometric Authentication to require fingerprint or face unlock when you return to the app.\n\nOpen your profile to update account details and theme preferences.',
                  ),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.privacy_tip_rounded,
                  iconColor: AppColors.info,
                  title: 'Privacy Policy',
                  subtitle: 'What stays local and what gets backed up',
                  onTap: () => _showInfoDialog(
                    title: 'Privacy Policy',
                    message:
                        'Project data stays on this device until you choose a Backup & Export action. Google backup uploads your account, projects, expenses, tasks, receipts metadata, and tags to your connected Google account. Biometric lock only protects local access on this device.',
                  ),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.description_outlined,
                  iconColor: AppColors.primary,
                  title: 'Terms of Service',
                  subtitle: 'Usage and responsibility summary',
                  onTap: () => _showInfoDialog(
                    title: 'Terms of Service',
                    message:
                        'You are responsible for the accuracy of project records, uploaded receipts, and exported reports. Cloud backup restores the latest uploaded snapshot for the connected Google account.',
                  ),
                ),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.support_agent_rounded,
                  iconColor: AppColors.success,
                  title: 'Copy Support Details',
                  subtitle: 'Copy app and sync status for troubleshooting',
                  onTap: _copySupportDetails,
                ),
                _buildAboutItem(isDark),
                _buildSettingsItem(
                  isDark: isDark,
                  icon: Icons.bug_report_rounded,
                  iconColor: AppColors.error,
                  title: 'Report a Bug',
                  subtitle: 'Steps to capture and share a good bug report',
                  onTap: () => _showInfoDialog(
                    title: 'Report a Bug',
                    message:
                        'Include what you were doing, what you expected, what happened instead, and whether Google backup or biometric lock was enabled. Use Copy Support Details first so you can paste the current app state into your report.',
                  ),
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
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
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

  String _googleSyncSubtitle() {
    if (_googleAccountEmail == null || _googleAccountEmail!.isEmpty) {
      return 'Connect Google Drive to back up projects and restore them on another device.';
    }

    final syncText = _lastSyncAt == null
        ? 'No backup uploaded yet'
        : 'Last sync ${DateFormat('yyyy-MM-dd HH:mm').format(_lastSyncAt!.toLocal())}';
    return 'Connected as $_googleAccountEmail. $syncText.';
  }

  Future<void> _handleBiometricToggle(bool enabled) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.toggleBiometric(enabled);
    if (!mounted) return;
    if (!ok) {
      _showSnackBar(
        auth.errorMessage ?? 'Unable to update biometric setting',
        AppColors.error,
      );
      return;
    }
    setState(() => _biometricAuth = enabled);
    _showSnackBar(
      enabled ? 'Biometric lock enabled' : 'Biometric lock disabled',
      AppColors.success,
    );
  }

  Future<void> _connectGoogleAccount() async {
    setState(() => _isSyncing = true);
    final result = await GoogleSyncService.instance.connectAccount();
    if (!mounted) return;
    if (result.success) {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final uid = db.activeUserId;
      if (uid != null) {
        await GoogleSyncService.instance.backupUserData(
          database: db.database,
          userId: uid,
          interactive: false,
        );
      }
      await _loadSettingsState();
    }
    setState(() => _isSyncing = false);
    _showSnackBar(
      result.message,
      result.success ? AppColors.success : AppColors.error,
    );
  }

  Future<void> _disconnectGoogleAccount() async {
    setState(() => _isSyncing = true);
    await GoogleSyncService.instance.disconnectAccount();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _googleAccountEmail = null;
      _lastSyncAt = null;
      _autoSyncEnabled = false;
    });
    _showSnackBar('Disconnected Google sync.', AppColors.warning);
  }

  Future<void> _backupNow() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final uid = db.activeUserId;
    if (uid == null) {
      _showSnackBar('Sign in before syncing.', AppColors.error);
      return;
    }

    setState(() => _isSyncing = true);
    final result = await GoogleSyncService.instance.backupUserData(
      database: db.database,
      userId: uid,
    );
    if (!mounted) return;
    setState(() => _isSyncing = false);
    if (result.success) {
      await _loadSettingsState();
    }
    _showSnackBar(
      result.message,
      result.success ? AppColors.success : AppColors.error,
    );
  }

  Future<void> _restoreFromGoogle() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final uid = db.activeUserId;
    if (uid == null) {
      _showSnackBar('Sign in before restoring.', AppColors.error);
      return;
    }

    setState(() => _isSyncing = true);
    final result = await GoogleSyncService.instance.restoreUserData(
      database: db.database,
      userId: uid,
    );
    if (!mounted) return;
    setState(() => _isSyncing = false);
    if (result.success) {
      db.setActiveUserId(uid);
      await _loadSettingsState();
    }
    _showSnackBar(
      result.message,
      result.success ? AppColors.success : AppColors.error,
    );
  }

  Future<void> _toggleAutoSync(bool enabled) async {
    await GoogleSyncService.instance.setAutoSyncEnabled(enabled);
    if (!mounted) return;
    setState(() => _autoSyncEnabled = enabled);
    _showSnackBar(
      enabled ? 'Auto-sync enabled' : 'Auto-sync disabled',
      enabled ? AppColors.success : AppColors.warning,
    );
  }

  Future<void> _exportAllProjectsAsExcel() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final projects = await db.getAllProjects();
    if (projects.isEmpty) {
      _showSnackBar('No projects available to export.', AppColors.warning);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final savedPath = await ExportService.instance.exportProjectsToExcel(
        projects: projects,
        expensesLoader: db.getExpensesByProject,
      );
      if (!mounted) return;
      await _showExportResultDialog(
        formatLabel: 'Excel',
        savedPath: savedPath,
      );
    } catch (e) {
      _showSnackBar('Excel export failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _exportAllProjectsAsCsv() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final projects = await db.getAllProjects();
    if (projects.isEmpty) {
      _showSnackBar('No projects available to export.', AppColors.warning);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final savedPath = await ExportService.instance.exportProjectsToCsv(
        projects: projects,
        expensesLoader: db.getExpensesByProject,
      );
      if (!mounted) return;
      await _showExportResultDialog(
        formatLabel: 'CSV',
        savedPath: savedPath,
      );
    } catch (e) {
      _showSnackBar('CSV export failed: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showExportResultDialog({
    required String formatLabel,
    required String savedPath,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$formatLabel Export Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Saved to:'),
              const SizedBox(height: 8),
              SelectableText(savedPath),
              const SizedBox(height: 12),
              const Text(
                'Choose Open File to let your device ask which viewer app to use.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: savedPath));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                _showSnackBar('File path copied', AppColors.success);
              },
              child: const Text('Copy Path'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await OpenFilex.open(savedPath);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (result.type != ResultType.done) {
                  _showSnackBar(
                    result.message.isEmpty
                        ? 'No viewer app was available to open this file.'
                        : result.message,
                    AppColors.warning,
                  );
                }
              },
              child: const Text('Open File'),
            ),
          ],
        );
      },
    );
  }

  void _showGoogleSyncSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup & Export Center',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _googleSyncSubtitle(),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-sync after changes'),
                  subtitle: const Text(
                    'Back up account, projects, expenses, and tasks after updates',
                  ),
                  value: _autoSyncEnabled,
                  onChanged: (_googleAccountEmail == null || _isSyncing)
                      ? null
                      : (value) async {
                          Navigator.pop(ctx);
                          await _toggleAutoSync(value);
                        },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSyncing
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              if (_googleAccountEmail == null) {
                                await _connectGoogleAccount();
                              } else {
                                await _backupNow();
                              }
                            },
                      icon: Icon(
                        _googleAccountEmail == null
                            ? Icons.account_circle_rounded
                            : Icons.cloud_upload_rounded,
                      ),
                      label: Text(
                        _googleAccountEmail == null
                            ? 'Connect Google'
                            : 'Backup now',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_googleAccountEmail == null || _isSyncing)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _restoreFromGoogle();
                            },
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: const Text('Restore backup'),
                    ),
                    if (_googleAccountEmail != null)
                      TextButton.icon(
                        onPressed: _isSyncing
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _disconnectGoogleAccount();
                              },
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Disconnect'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isSyncing
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _exportAllProjectsAsExcel();
                            },
                      icon: const Icon(Icons.table_chart_rounded),
                      label: const Text('Export Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSyncing
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _exportAllProjectsAsCsv();
                            },
                      icon: const Icon(Icons.grid_on_rounded),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportLocalBackup(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dbp = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid == null) {
      _showSnackBar('Sign in to export a backup.', AppColors.warning);
      return;
    }
    setState(() => _backupBusy = true);
    try {
      final path = await BackupService.exportToFile(
        dbp.database,
        userId: uid,
      );
      if (!mounted) return;
      if (path != null) {
        _showSnackBar('Backup saved.', AppColors.success);
      } else {
        _showSnackBar('Export cancelled.', AppColors.info);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Export failed: $e', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dbp = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid == null) {
      _showSnackBar('Sign in to restore.', AppColors.warning);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will replace ALL current data for this account. '
          'This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace data'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _restoreBusy = true);
    try {
      final text = await BackupService.pickAndReadBackupFile();
      if (text == null) {
        if (mounted) {
          _showSnackBar('No file selected.', AppColors.info);
        }
        return;
      }
      final err = BackupService.validateBackupJson(text);
      if (err != null) {
        if (mounted) _showSnackBar(err, AppColors.error);
        return;
      }
      await BackupService.restoreFromJsonString(
        dbp.database,
        userId: uid,
        jsonSource: text,
      );
      dbp.notifyDatabaseChanged();
      if (mounted) {
        _showSnackBar('Restore completed.', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Restore failed: $e', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copySupportDetails() async {
    final syncState = _googleAccountEmail == null
        ? 'Not connected'
        : _googleAccountEmail!;
    final syncTime = _lastSyncAt == null
        ? 'No cloud backup yet'
        : DateFormat('yyyy-MM-dd HH:mm').format(_lastSyncAt!.toLocal());
    final details =
        '''
ProjectRack 2.4.0
Google account: $syncState
Last sync: $syncTime
Auto-sync: ${_autoSyncEnabled ? 'Enabled' : 'Disabled'}
Biometric lock: ${_biometricAuth ? 'Enabled' : 'Disabled'}
''';
    await Clipboard.setData(ClipboardData(text: details.trim()));
    if (!mounted) return;
    _showSnackBar('Support details copied', AppColors.success);
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
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
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
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
        child: Icon(icon, color: iconColor, size: 20),
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
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        activeTrackColor: AppColors.primaryLight,
        inactiveThumbColor: isDark ? AppColors.darkTextTertiary : Colors.grey,
        inactiveTrackColor: isDark
            ? AppColors.darkBorder
            : AppColors.lightBorder,
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
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          onTap: () async {
            final chosen = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
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
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                      ...CurrencyProvider.options.map(
                        (opt) => ListTile(
                          title: Text(opt.label),
                          selected: currency.currencyCode == opt.code,
                          onTap: () => Navigator.pop(ctx, opt.code),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (chosen != null) await currency.setCurrency(chosen);
          },
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ),
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
        child: Icon(icon, color: iconColor, size: 20),
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
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
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
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${usedStorage.toStringAsFixed(1)} GB of $totalStorage GB used',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 2.4.0 (Build 2401)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '© 2024 ProjectRack Inc.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
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
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
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
            Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final db = Provider.of<DriftDatabaseProvider>(
                context,
                listen: false,
              );
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

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data. You will need to download some content again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
