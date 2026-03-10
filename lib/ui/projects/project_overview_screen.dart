// lib/screens/project_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';

import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectOverviewScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  bool _isInProgress = true;
  double _completionPercentage = 0.75; // 75%

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: (isDark ? AppColors.darkBackground : Colors.white).withOpacity(0.9),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 20,
                    ),
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ),
                title: Text(
                  widget.projectName,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: true,
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                      onPressed: () {
                        // Navigate to project settings
                      },
                    ),
                  ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // Status Badge
                    Center(
                      child: _buildStatusBadge(isDark),
                    ),

                    const SizedBox(height: 24),

                    // Financial Card
                    _buildFinancialCard(isDark),

                    const SizedBox(height: 32),

                    // Quick Actions
                    _buildQuickActions(isDark),

                    const SizedBox(height: 32),

                    // Team Section
                    _buildTeamSection(isDark),

                    const SizedBox(height: 32),

                    // Recent Activity
                    _buildRecentActivity(isDark),

                    const SizedBox(height: 100), // Space for bottom bar
                  ]),
                ),
              ),
            ],
          ),

          // Custom Bottom Navigation with FAB
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCustomBottomNav(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const IgnorePointer(
              child: SizedBox.expand(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'In Progress',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background glow
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL SPEND',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '\$12,450',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Budget remaining: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              const Text(
                '\$2,550',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Project Completion',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(_completionPercentage * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: _completionPercentage,
                  backgroundColor: Colors.black.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                icon: Icons.edit_note_rounded,
                iconColor: AppColors.primary,
                title: 'Log Entry',
                subtitle: 'Daily material entry',
                onTap: () {
                  context.push('/project/${widget.projectId}/material-entry', extra: widget.projectName);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                icon: Icons.history_rounded,
                iconColor: isDark ? Colors.white : Colors.black,
                title: 'View Logs',
                subtitle: 'Logs by date',
                onTap: () {
                  context.push('/project/${widget.projectId}/logs-history', extra: widget.projectName);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.primary,
                title: 'Tasks',
                subtitle: 'Open / Total',
                onTap: () {
                  // Navigate to tasks when screen exists
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                icon: Icons.receipt_long_rounded,
                iconColor: isDark ? Colors.white : Colors.black,
                title: 'Expenses',
                subtitle: 'Project expenses',
                onTap: () {
                  context.push('/project/${widget.projectId}/expenses', extra: widget.projectName);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFullWidthActionCard(
          isDark: isDark,
          icon: Icons.analytics_rounded,
          iconColor: AppColors.primary,
          title: 'Project Report',
          subtitle: 'Weekly analytics ready',
          onTap: () {
            context.push('/project/${widget.projectId}/reports', extra: widget.projectName);
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSection(bool isDark) {
    final List<String> teamImages = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBXv0BKw-vyN7CdCIQLsD5w5QNDzX2nBM6QZoJ9bP5Vmp3M68Xhg-d-GY18NCZ9FZ0-6vE2oaWBguE57ewBeVZfOjnev_2f5pa9kiATUd-wq0a3_tRQ4QTijd2tsSh_O1sMHMqA6Acn9XtCzNMpHbcFw229JZY8x56ddYOnVDqZRRpRUWRUfHDvbKlsRSGQCZ8bQWHnPhbjYkcZftp-ktKGIhEl_LyH8bZUZV0mAHkCrp7GO7BWmbNXnQJdZue8hw1wrVYmqwdFW3cm',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDMSDN8sOTnj-vljl42IHWeQSS4nQivWLjqGIPPDcGdZ3iaYP8FrTZvkr0tT7dkSmLK1LCZYSEBzuiO2KUcEvYRHzULTjxatyXxUHNbUY1zTqD5ZvtyWzVzl2GxTHqDjo5iKj64dNGe9xPRx3IB1CF49BRoZNVcedGjXaq6ot6Tmhxim3VQ44tgF7_8sJz9E_K-rAMlPQ25YTh902Pl09HnwLaz8nPIyrosjY9k10xVRnSqfG3LLqKUNkf95KG8Q0Y9rF1tgXuBLn8u',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC50e29BdI6ungINu2EApqhXuIRQkMuWrWlbOronM1SWMYh88-wgflKQ1beFO1iHLoyBucipzF3ZONKBG-6HnIACPHSHMn154EADFjjynSi-C_Nkzep28RUEXca6LEQeVrcGMWGLjTsALY7K4bh5fBeKZpyBO4suqeYXWpbLPUut3COV9Ib47ZZHsfV4xXJthgR2BjPnVGnJLgtOKVX_sHGJjG2urZT5ckDvL_7UFkpJc1DJXsbHOxjB8SGSdh-ayZWwstmD1KM4lBF',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Team',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to team management
              },
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Team avatars
              ...teamImages.asMap().entries.map((entry) {
                return Container(
                  width: 48,
                  height: 48,
                  margin: EdgeInsets.only(left: entry.key == 0 ? 0 : -12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppColors.darkBackground : Colors.white,
                      width: 3,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.network(
                      entry.value,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                          child: Center(
                            child: Text(
                              '👤',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),

              // More count
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(left: -12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  border: Border.all(
                    color: isDark ? AppColors.darkBackground : Colors.white,
                    width: 3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '+2',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Invite button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showInviteBottomSheet(context, isDark);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_rounded,
                          size: 16,
                          color: isDark ? AppColors.primary : Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Invite',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primary : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    final activities = [
      {
        'icon': Icons.receipt_rounded,
        'iconColor': isDark ? Colors.white : Colors.grey.shade600,
        'bgColor': isDark ? AppColors.darkSurface : Colors.grey.shade100,
        'title': 'New receipt added',
        'subtitle': 'John uploaded "Server Costs" for \$450.00',
        'time': '2h ago',
      },
      {
        'icon': Icons.check_rounded,
        'iconColor': AppColors.primary,
        'bgColor': AppColors.primary.withOpacity(0.2),
        'title': 'Task completed',
        'subtitle': 'Sarah finished "Wireframe Homepage"',
        'time': '5h ago',
      },
      {
        'icon': Icons.comment_rounded,
        'iconColor': isDark ? Colors.white : Colors.grey.shade600,
        'bgColor': isDark ? AppColors.darkSurface : Colors.grey.shade100,
        'title': 'New comment',
        'subtitle': 'Mike commented on "Q3 Strategy"',
        'time': '1d ago',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            children: activities.map((activity) {
              return _buildActivityItem(
                isDark: isDark,
                icon: activity['icon'] as IconData,
                iconColor: activity['iconColor'] as Color,
                bgColor: activity['bgColor'] as Color,
                title: activity['title'] as String,
                subtitle: activity['subtitle'] as String,
                time: activity['time'] as String,
                isLast: activities.indexOf(activity) == activities.length - 1,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
        color: isDark ? AppColors.darkSurface : Colors.white,
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                isDark: isDark,
                icon: Icons.grid_view_rounded,
                label: 'Overview',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavItem(
                isDark: isDark,
                icon: Icons.format_list_bulleted_rounded,
                label: 'Tasks',
                isSelected: false,
                onTap: () {},
              ),

              // FAB with glow effect
              GestureDetector(
                onTap: _showActionBottomSheet,
                child: Container(
                  transform: Matrix4.translationValues(0, -15, 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),
              ),

              _buildNavItem(
                isDark: isDark,
                icon: Icons.attach_money_rounded,
                label: 'Budget',
                isSelected: false,
                onTap: () {},
              ),
              _buildNavItem(
                isDark: isDark,
                icon: Icons.folder_open_rounded,
                label: 'Files',
                isSelected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required bool isDark,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionBottomSheet() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildActionBottomSheet(isDark),
    );
  }

  Widget _buildActionBottomSheet(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Options
          _buildActionOption(
            isDark: isDark,
            icon: Icons.camera_alt_rounded,
            iconColor: AppColors.primary,
            title: 'Capture Receipt',
            subtitle: 'Take a photo of a receipt to track expenses',
            onTap: () {
              Navigator.pop(context);
              _handleCaptureReceipt();
            },
          ),

          _buildActionOption(
            isDark: isDark,
            icon: Icons.create_new_folder_rounded,
            iconColor: AppColors.secondary,
            title: 'Create New Project',
            subtitle: 'Start a new project with details',
            onTap: () {
              Navigator.pop(context);
              _handleCreateProject();
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCaptureReceipt() {
    context.push(AppRoutes.receiptOcr, extra: {'projectId': widget.projectId});
  }

  void _handleCreateProject() {
    // Navigate to create project screen
    context.push('/create-project');
  }

  void _showInviteBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Invite Team Member',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon: const Icon(Icons.email_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send Invite'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}