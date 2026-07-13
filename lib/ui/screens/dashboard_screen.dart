// lib/ui/dashboard/dashboard_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/providers/dashboard_data.dart';
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
  StreamSubscription<DashboardData>? _dashboardSub;
  DashboardData _data = DashboardData.empty();
  bool _loading = true;

  static const int _insightsDays = 30;

  static String _greetingForTime(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      _dashboardSub?.cancel();
      _dashboardSub = db.dashboardDataStream.listen(
        (data) {
          if (!mounted) return;
          setState(() {
            _data = data;
            _loading = false;
          });
        },
        onError: (e) {
          debugPrint('Dashboard stream error: $e');
          if (mounted) setState(() => _loading = false);
        },
      );
      // Seed immediately — broadcast streams can miss the first emit.
      final uid = db.activeUserId;
      if (uid != null) {
        db.buildDashboardData(uid).then((data) {
          if (!mounted) return;
          setState(() {
            _data = data;
            _loading = false;
          });
        });
      } else {
        setState(() {
          _data = DashboardData.empty();
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _dashboardSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final userName = auth.currentUser?.name ?? 'User';
    final greeting = _greetingForTime(DateTime.now());

    final subtitle =
        '${_data.activeProjectCount} active projects · ${_data.pendingTasks} open tasks';
    final recentProjects = _data.recentProjects;
    final insightsSeries = _data.insightsSeries;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // 1. Dashboard Header: Top Bar matching redesigned specs
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
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    size: 24,
                  ),
                  onPressed: () => context.go(AppRoutes.notifications),
                ),
              ),
            ],
          ),

          // 2. Greeting Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $userName',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Stats Row: Three individual horizontal cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Consumer<CurrencyProvider>(
                builder: (_, currency, _) => Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        isDark: isDark,
                        label: 'Projects',
                        value: '${_data.projectCount}',
                        onTap: () => context.go(AppRoutes.projects),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        isDark: isDark,
                        label: 'Spent',
                        value: currency.format(_data.totalSpent),
                        valueFontSize: 15,
                        onTap: () => context.go(AppRoutes.reportsAnalytics),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Spending Trend Section Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spending trend',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.reportsAnalytics),
                    child: Text(
                      'Reports →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Spending Trend Card (Sparkline chart, cumulated spending, and legend)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Consumer<CurrencyProvider>(
                builder: (_, currency, _) => GestureDetector(
                  onTap: () => context.go(AppRoutes.reportsAnalytics),
                  child: _buildInsightsCard(
                    isDark: isDark,
                    currency: currency,
                    insightsSeries: insightsSeries,
                  ),
                ),
              ),
            ),
          ),

          // 5. Projects Section Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent projects',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.projects),
                    child: Text(
                      'See all →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Projects List (Compact rows, no network images, offline friendly)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _loading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : recentProjects.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_special_rounded,
                                size: 48,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No projects yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a project to track budget and materials.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () => context.go(AppRoutes.createProject),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('New project'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index.isOdd) return const SizedBox(height: 8);
                            final project = recentProjects[index ~/ 2];
                            final currency = Provider.of<CurrencyProvider>(context);
                            return _buildProjectRow(
                              isDark: isDark,
                              project: project,
                              currency: currency,
                            );
                          },
                          childCount: recentProjects.isEmpty ? 0 : recentProjects.length * 2 - 1,
                        ),
                      ),
          ),

          // 6. Leave bottom padding (80-100px) for bottom nav bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 90),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String label,
    required String value,
    String? subtitle,
    double valueFontSize = 18,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ] else
                const SizedBox(height: 13), // Preserve spacing consistency
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, bool isDark, String? avatarUrl) {
    final imageProvider = avatarImageProvider(avatarUrl);
    final hasImage = imageProvider != null;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? null : AppColors.info.withOpacity(0.2),
        border: Border.all(
          color: AppColors.info,
          width: 1.5,
        ),
        image: hasImage
            ? DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage
          ? null
          : Icon(
              Icons.person_rounded,
              color: AppColors.info,
              size: 20,
            ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.info;
      case 'Done':
        return AppColors.success;
      case 'On Hold':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildProjectRow({
    required bool isDark,
    required Project project,
    required CurrencyProvider currency,
  }) {
    final statusColor = _statusColor(project.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push(
            AppRoutes.projectOverview.replaceFirst(':id', project.id),
            extra: project.name,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : AppColors.lightBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top portion: Name + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      project.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Bottom portion: Progress Bar + Percentage + Budget Spent
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: project.progress.clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(project.progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${currency.format(project.spent)} / ${currency.format(project.budget)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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

  Widget _buildInsightsCard({
    required bool isDark,
    required CurrencyProvider currency,
    required List<DashboardInsightSeries> insightsSeries,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const SizedBox(
              height: 88,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (insightsSeries.isEmpty)
            SizedBox(
              height: 88,
              child: Center(
                child: Text(
                  'No recent expense data yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 88,
              child: LineChart(
                _buildLineChartData(isDark, insightsSeries),
                duration: Duration.zero,
              ),
            ),
          if (!_loading && insightsSeries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: insightsSeries
                  .map(
                    (s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          s.projectName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(
    bool isDark,
    List<DashboardInsightSeries> insightsSeries,
  ) {
    double maxY = 0;
    for (final s in insightsSeries) {
      for (final spot in s.spots) {
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    if (maxY <= 0) maxY = 1;

    return LineChartData(
      minX: 0,
      maxX: (_insightsDays - 1).toDouble(),
      minY: 0,
      maxY: maxY * 1.1,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 3,
        getDrawingHorizontalLine: (_) => FlLine(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              if (spot.barIndex < 0 || spot.barIndex >= insightsSeries.length) {
                return null;
              }
              final series = insightsSeries[spot.barIndex];
              return LineTooltipItem(
                '${series.projectName}\n${spot.y.toStringAsFixed(0)}',
                TextStyle(
                  color: series.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: insightsSeries
          .map(
            (s) => LineChartBarData(
              spots: s.spots,
              isCurved: true,
              color: s.color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: s.color.withOpacity(0.08),
              ),
            ),
          )
          .toList(),
    );
  }
}
