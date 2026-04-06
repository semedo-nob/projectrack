// lib/ui/dashboard/dashboard_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  StreamSubscription<List<Project>>? _projectsSub;
  int _projectCount = 0;
  double _totalSpent = 0;
  int _pendingTasks = 0;

  bool _loadingInsights = true;
  List<_InsightsSeries> _insightsSeries = const [];
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
      _loadProjects();
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      _projectsSub?.cancel();
      _projectsSub = db.projectsStream.listen((_) => _loadProjects());
    });
  }

  @override
  void dispose() {
    _projectsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final list = await db.getAllProjects();
    final stats = await db.getDashboardStats();
    final insights = await _buildInsightsSeries(db, list);
    if (!mounted) return;
    setState(() {
      _projects = list;
      _loadingProjects = false;
      _projectCount = stats['projectCount'] as int? ?? list.length;
      _totalSpent = (stats['totalSpent'] as num?)?.toDouble() ?? 0;
      _pendingTasks = stats['pendingTasks'] as int? ?? 0;
      _insightsSeries = insights;
      _loadingInsights = false;
    });
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<List<_InsightsSeries>> _buildInsightsSeries(
    DriftDatabaseProvider db,
    List<Project> projects,
  ) async {
    final now = DateTime.now();
    final start = _dateOnly(now.subtract(const Duration(days: _insightsDays - 1)));

    if (projects.isEmpty) return const [];

    // Build daily spend per project for last N days.
    final perProjectDaily = <String, List<double>>{};
    final perProjectName = <String, String>{};
    final perProjectTotal = <String, double>{};

    for (final p in projects) {
      perProjectName[p.id] = p.name;
      perProjectDaily[p.id] = List<double>.filled(_insightsDays, 0);

      final expenses = await db.getExpensesByProject(p.id);
      for (final e in expenses) {
        final d = _dateOnly(e.date);
        final idx = d.difference(start).inDays;
        if (idx < 0 || idx >= _insightsDays) continue;
        perProjectDaily[p.id]![idx] += e.amount;
        perProjectTotal[p.id] = (perProjectTotal[p.id] ?? 0) + e.amount;
      }
    }

    // Show up to top 3 projects by spend in the window.
    final topProjectIds = perProjectTotal.keys.toList()
      ..sort((a, b) => (perProjectTotal[b] ?? 0).compareTo(perProjectTotal[a] ?? 0));

    final selected = topProjectIds.take(3).toList();
    if (selected.isEmpty) return const [];

    const palette = <Color>[
      AppColors.primary,
      AppColors.success,
      AppColors.secondary,
    ];

    final series = <_InsightsSeries>[];
    for (var i = 0; i < selected.length; i++) {
      final id = selected[i];
      final daily = perProjectDaily[id] ?? List<double>.filled(_insightsDays, 0);

      // Convert to cumulative spend for a smooth trend line.
      double running = 0;
      final spots = <FlSpot>[];
      for (var x = 0; x < daily.length; x++) {
        running += daily[x];
        spots.add(FlSpot(x.toDouble(), running));
      }

      series.add(
        _InsightsSeries(
          projectId: id,
          projectName: perProjectName[id] ?? 'Project',
          color: palette[i % palette.length],
          spots: spots,
        ),
      );
    }

    return series;
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

          // Greeting — one scannable line
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                '$greeting, $userName',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Your projects and spending at a glance',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),

          // Single summary card: projects · spent · tasks
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Consumer<CurrencyProvider>(
                builder: (_, currency, _) => Material(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => context.go(AppRoutes.projects),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: _buildMetricCell(
                                isDark: isDark,
                                label: 'Projects',
                                value: '$_projectCount',
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 52,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.08),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => context.go(AppRoutes.reportsAnalytics),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: _buildMetricCell(
                                isDark: isDark,
                                label: 'Spent',
                                value: currency.format(_totalSpent),
                                valueFontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 52,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.08),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => context.go(AppRoutes.projects),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: _buildMetricCell(
                                isDark: isDark,
                                label: 'Tasks',
                                value: '$_pendingTasks',
                                subtitle: 'open',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Reports Summary Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Consumer<CurrencyProvider>(
                builder: (_, currency, _) => GestureDetector(
                  onTap: () => context.go(AppRoutes.reportsAnalytics),
                  child: _buildInsightsCard(isDark: isDark, currency: currency),
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

  Widget _buildMetricCell({
    required bool isDark,
    required String label,
    required String value,
    String? subtitle,
    double valueFontSize = 17,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
      ],
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
                image: imageProvider,
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
                    // Thumbnail (no network placeholder — avoids offline SocketException)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: ColoredBox(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          child: project.imageUrl.isNotEmpty
                              ? Image.network(
                                  project.imageUrl,
                                  fit: BoxFit.cover,
                                  width: 96,
                                  height: 96,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.folder_rounded,
                                        size: 40,
                                        color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Icon(
                                    Icons.folder_rounded,
                                    size: 40,
                                    color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
                                  ),
                                ),
                        ),
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

  Widget _buildInsightsCard({
    required bool isDark,
    required CurrencyProvider currency,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending trend',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last $_insightsDays days · ${currency.symbol} · tap for reports',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingInsights)
            const SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_insightsSeries.isEmpty)
            SizedBox(
              height: 110,
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
                _buildLineChartData(isDark),
                duration: Duration.zero,
              ),
            ),
          if (!_loadingInsights && _insightsSeries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: _insightsSeries
                  .map(
                    (s) => _LegendChip(
                      label: s.projectName,
                      color: s.color,
                      isDark: isDark,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(bool isDark) {
    double maxY = 0;
    for (final s in _insightsSeries) {
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
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 18,
            interval: 7,
            getTitlesWidget: (value, meta) {
              final v = value.toInt();
              if (v % 7 != 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_insightsDays - 1 - v}d',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => isDark ? AppColors.darkSurface : Colors.white,
          tooltipBorder: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
          ),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final series = _insightsSeries[spot.barIndex];
              return LineTooltipItem(
                '${series.projectName}\n${spot.y.toStringAsFixed(0)}',
                TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: _insightsSeries
          .map(
            (s) => LineChartBarData(
              spots: s.spots,
              isCurved: true,
              barWidth: 2.5,
              color: s.color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: s.color.withOpacity(0.10),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InsightsSeries {
  final String projectId;
  final String projectName;
  final Color color;
  final List<FlSpot> spots;

  const _InsightsSeries({
    required this.projectId,
    required this.projectName,
    required this.color,
    required this.spots,
  });
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _LegendChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}