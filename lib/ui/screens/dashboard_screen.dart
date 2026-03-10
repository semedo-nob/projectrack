// lib/ui/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/avatar_image.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Project> _projects = [];
  bool _loadingProjects = true;
  int _projectCount = 0;
  double _totalSpent = 0;
  int _pendingTasks = 0;

  static String _greetingForTime(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
  }

  Future<void> _loadProjects() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final list = await db.getAllProjects();
    final stats = await db.getDashboardStats();
    if (!mounted) return;
    setState(() {
      _projects = list;
      _loadingProjects = false;
      _projectCount = stats['projectCount'] as int? ?? list.length;
      _totalSpent = (stats['totalSpent'] as num?)?.toDouble() ?? 0;
      _pendingTasks = stats['pendingTasks'] as int? ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final userName = auth.currentUser?.name ?? 'User';
    final greeting = _greetingForTime(DateTime.now());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Top App Bar
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.9),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => context.go(AppRoutes.profile),
                child: _buildUserAvatar(context, isDark, auth.currentUser?.avatarUrl),
              ),
            ),
            title: Text(
              'ProjectRack',
              style: theme.appBarTheme.titleTextStyle?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: false,
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 28,
                  ),
                  onPressed: () => context.go(AppRoutes.notifications),
                ),
              ),
            ],
          ),

          // Headline Text
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$greeting, $userName',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats Cards (real data; currency from CurrencyProvider)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Consumer<CurrencyProvider>(
                builder: (_, currency, __) => Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go(AppRoutes.projects),
                        child: _buildStatCard(
                          isDark: isDark,
                          icon: Icons.folder_open_rounded,
                          iconColor: AppColors.primary,
                          bgColor: isDark ? AppColors.darkCard : Colors.white,
                          label: 'Active Projects',
                          value: '$_projectCount',
                          badge: _pendingTasks > 0 ? '$_pendingTasks tasks' : 'Active',
                          badgeColor: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go(AppRoutes.categorizedExpenses.replaceFirst(':id', 'default'), extra: 'Expenses'),
                        child: _buildStatCard(
                          isDark: isDark,
                          icon: Icons.payments_rounded,
                          iconColor: isDark ? AppColors.darkBackground : Colors.white,
                          bgColor: isDark ? AppColors.primary : AppColors.primaryDark,
                          label: 'Total Expenses',
                          value: currency.format(_totalSpent),
                          badge: 'Spent',
                          badgeColor: AppColors.primaryLight,
                          isDarkCard: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Reports Summary Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => context.go(AppRoutes.reportsAnalytics),
                child: _buildStatCard(
                  isDark: isDark,
                  icon: Icons.analytics_rounded,
                  iconColor: isDark ? AppColors.darkBackground : AppColors.primary,
                  bgColor: isDark ? AppColors.darkCard : Colors.white,
                  label: 'Reports & Analytics',
                  value: 'View insights',
                  badge: 'Reports',
                  badgeColor: AppColors.secondary,
                ),
              ),
            ),
          ),

          // Section Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Projects',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.projects),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ),

          // Projects List (from database; tap -> project details)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _loadingProjects
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : _projects.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No projects yet. Create one from the Projects tab.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index.isOdd) return const SizedBox(height: 16);
                            final project = _projects[index ~/ 2];
                            final currency = Provider.of<CurrencyProvider>(context);
                            return _buildProjectCard(
                              isDark: isDark,
                              project: project,
                              currency: currency,
                            );
                          },
                          childCount: _projects.isEmpty ? 0 : _projects.length * 2 - 1,
                        ),
                      ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, bool isDark, String? avatarUrl) {
    final imageProvider = avatarImageProvider(avatarUrl);
    final hasImage = imageProvider != null;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? null : AppColors.primary.withOpacity(0.2),
        border: Border.all(
          color: AppColors.primary,
          width: 2,
        ),
        image: hasImage
            ? DecorationImage(
                image: imageProvider!,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage
          ? null
          : Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 24,
            ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String badge,
    required Color badgeColor,
    bool isDarkCard = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkCard
                      ? Colors.white.withOpacity(0.1)
                      : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkCard
                      ? Colors.white.withOpacity(0.1)
                      : badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkCard ? Colors.white : badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkCard
                  ? Colors.white.withOpacity(0.7)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkCard
                  ? Colors.white
                  : (isDark ? AppColors.darkText : AppColors.lightText),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.primary;
      case 'Done':
        return AppColors.success;
      case 'On Hold':
        return AppColors.warning;
      default:
        return AppColors.primaryMuted;
    }
  }

  Widget _buildProjectCard({
    required bool isDark,
    required Project project,
    required CurrencyProvider currency,
  }) {
    final statusColor = _statusColor(project.status);
    final progressColor = project.status == 'Done' ? AppColors.success : null;
    final imageUrl = project.imageUrl.isNotEmpty
        ? project.imageUrl
        : 'https://via.placeholder.com/96?text=';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/project/${project.id}', extra: project.name);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        image: imageUrl.startsWith('http')
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  project.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkText : AppColors.lightText,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  project.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expenses'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                              children: [
                                TextSpan(text: currency.format(project.spent)),
                                TextSpan(
                                  text: ' / ${currency.format(project.budget)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${(project.progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progressColor ?? AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: project.progress.clamp(0.0, 1.0),
                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor ?? AppColors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}