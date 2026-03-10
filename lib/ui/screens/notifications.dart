// lib/ui/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final list = await db.getProjectNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications.where((n) {
      final type = n['type'] as String?;
      if (_selectedFilter == 'Tasks' && type == 'task') return true;
      if (_selectedFilter == 'Budgets' && type == 'budget') return true;
      if (_selectedFilter == 'Projects' && (type == 'activity' || type == 'status' || type == 'asset')) return true;
      return false;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedNotifications {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var notification in _filteredNotifications) {
      final section = notification['section'] as String;
      grouped.putIfAbsent(section, () => []).add(notification);
    }
    return grouped;
  }

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n['unread'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  void _openProject(Map<String, dynamic> notification) {
    final projectId = notification['projectId'] as String?;
    final projectName = notification['projectName'] as String?;
    if (projectId == null || projectId.isEmpty) return;
    setState(() => notification['unread'] = false);
    context.push('/project/$projectId', extra: projectName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(isDark),

            // Filter Chips
            _buildFilterChips(isDark),

            // Notifications List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _buildNotificationsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => context.go(AppRoutes.home),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                size: 20,
              ),
            ),
          ),

          const Spacer(),

          // Title
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),

          const Spacer(),

          // Mark All Read Button
          TextButton(
            onPressed: _markAllAsRead,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['All', 'Tasks', 'Budgets', 'Projects'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                isDark: isDark,
                label: filter,
                isSelected: isSelected,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required bool isDark,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? null
              : Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.black
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(bool isDark) {
    final grouped = _groupedNotifications;

    if (grouped.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primary,
      child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            _buildSectionHeader(isDark, entry.key),
            const SizedBox(height: 8),

            // Notifications in this section
            ...entry.value.map((notification) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildNotificationItem(
                  isDark: isDark,
                  notification: notification,
                  onTap: () => _openProject(notification),
                ),
              );
            }),

            const SizedBox(height: 16),
          ],
        );
      }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem({
    required bool isDark,
    required Map<String, dynamic> notification,
    VoidCallback? onTap,
  }) {
    final hasUnreadDot = notification['unread'] == true;
    final hasAction = notification['action'] == true;
    final hasChevron = notification['hasChevron'] == true;
    final opacity = notification['opacity'] ?? 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Unread Dot
            if (hasUnreadDot)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Content Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: notification['iconBgColor'],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notification['icon'],
                          color: notification['iconColor'],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification['time'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                children: _parseDescription(notification['description']?.toString() ?? ''),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chevron (if needed)
                      if (hasChevron)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                    ],
                  ),

                  // Action Button (if needed)
                  if (hasAction)
                    Padding(
                      padding: const EdgeInsets.only(left: 64, top: 8),
                      child: TextButton(
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          notification['actionLabel'] ?? 'Review',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  List<TextSpan> _parseDescription(String description) {
    final spans = <TextSpan>[];
    final regex = RegExp(r"'([^']*)'");
    int lastIndex = 0;

    for (final match in regex.allMatches(description)) {
      // Add text before the quoted part
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: description.substring(lastIndex, match.start)));
      }

      // Add the quoted part with bold styling
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < description.length) {
      spans.add(TextSpan(text: description.substring(lastIndex)));
    }

    return spans;
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.done_all_rounded,
            size: 64,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "You're all caught up",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}