// lib/ui/reports/reports_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  final String? projectId;
  final String? projectName;

  const ReportsAnalyticsScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  String _selectedDateFilter = 'This Month';
  bool _loading = true;
  double _totalSpent = 0;
  double _totalBudget = 0;
  double _remaining = 0;
  int _pendingTasks = 0;
  int _taskDone = 0;
  int _taskTotal = 0;
  List<Map<String, dynamic>> _categoryBreakdown = [];
  static const List<Color> _categoryColors = [
    AppColors.primary,
    AppColors.success,
    AppColors.secondary,
    AppColors.warning,
    AppColors.info,
    AppColors.error,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReportData());
  }

  Future<void> _loadReportData() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final stats = await db.getDashboardStats();
    _totalBudget = (stats['totalBudget'] as num?)?.toDouble() ?? 0;
    _totalSpent = (stats['totalSpent'] as num?)?.toDouble() ?? 0;
    _remaining = (stats['remainingBudget'] as num?)?.toDouble() ?? (_totalBudget - _totalSpent);
    _pendingTasks = stats['pendingTasks'] as int? ?? 0;

    final projects = await db.getAllProjects();
    final projectIds = widget.projectId != null && widget.projectId!.isNotEmpty
        ? [widget.projectId!]
        : projects.map((p) => p.id).toList();

    final categoryTotals = <String, double>{};
    int taskDone = 0;
    int taskTotal = 0;

    for (final id in projectIds) {
      final expenses = await db.getExpensesByProject(id);
      for (final e in expenses) {
        final cat = e.category.displayName;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }
      final tasks = await db.getTasksByProject(id);
      taskTotal += tasks.length;
      for (final t in tasks) {
        if (t.status == 'Done') taskDone++;
      }
    }

    _taskTotal = taskTotal;
    _taskDone = taskDone;

    final totalCat = categoryTotals.values.fold(0.0, (a, b) => a + b);
    int idx = 0;
    _categoryBreakdown = categoryTotals.entries.map((e) {
      final pct = totalCat > 0 ? e.value / totalCat : 0.0;
      final color = _categoryColors[idx % _categoryColors.length];
      idx++;
      return {
        'label': e.key,
        'amount': e.value,
        'percentage': pct,
        'color': color,
        'pctLabel': totalCat > 0 ? '${(pct * 100).round()}%' : '0%',
      };
    }).toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);

    final currency = Provider.of<CurrencyProvider>(context);
    final reportTitle = widget.projectName ?? 'All Projects';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with Glass Effect
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withOpacity(0.7)
                    : Colors.white.withOpacity(0.9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        onPressed: () => context.go(AppRoutes.home),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports & Analytics',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reportTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Share Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.ios_share_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        // Share report
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _loadReportData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),

                            // Date Filters
                            _buildDateFilters(isDark),

                            const SizedBox(height: 16),

                            // Key Metrics Cards
                            _buildMetricsCards(isDark, currency),

                    const SizedBox(height: 24),

                    // Spending Over Time Chart
                    _buildSpendingChart(isDark, currency),

                    const SizedBox(height: 24),

                    // Expense by Category
                    _buildExpenseCategory(isDark, currency),

                    const SizedBox(height: 24),

                    // Task Completion & Budget
                    _buildTaskAndBudget(isDark, currency),

                    const SizedBox(height: 24),

                    // Insights Alert
                    _buildInsightsAlert(isDark),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilters(bool isDark) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildFilterChip(
            label: 'This Month',
            isSelected: _selectedDateFilter == 'This Month',
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: 'Last 30 Days',
            isSelected: _selectedDateFilter == 'Last 30 Days',
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: 'This Quarter',
            isSelected: _selectedDateFilter == 'This Quarter',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.black
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.black,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards(bool isDark, CurrencyProvider currency) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildMetricCard(
            isDark: isDark,
            icon: Icons.payments_rounded,
            iconColor: AppColors.primary,
            bgColor: AppColors.primary.withOpacity(0.2),
            label: 'Total Spent',
            value: currency.format(_totalSpent),
            trendIcon: Icons.pie_chart_rounded,
            trendColor: AppColors.primary,
            trendValue: 'All projects',
            trendLabel: '',
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            isDark: isDark,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.warning,
            bgColor: AppColors.warning.withOpacity(0.2),
            label: 'Remaining',
            value: currency.format(_remaining),
            trendIcon: _remaining >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            trendColor: _remaining >= 0 ? AppColors.success : AppColors.error,
            trendValue: _totalBudget > 0 ? '${((_remaining / _totalBudget) * 100).round()}% of budget' : '—',
            trendLabel: '',
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            isDark: isDark,
            icon: Icons.pending_actions_rounded,
            iconColor: AppColors.secondary,
            bgColor: AppColors.secondary.withOpacity(0.2),
            label: 'Pending Tasks',
            value: '$_pendingTasks',
            trendIcon: _taskTotal > 0 ? Icons.check_circle_rounded : Icons.assignment_rounded,
            trendColor: AppColors.success,
            trendValue: _taskTotal > 0 ? '$_taskDone / $_taskTotal done' : 'No tasks',
            showTrendLabel: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required IconData trendIcon,
    required Color trendColor,
    required String trendValue,
    String? trendLabel,
    bool showTrendLabel = true,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
        ),
      ),
      child: Stack(
        children: [
          // Background glow
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.1),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Value
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),

              const SizedBox(height: 4),

              // Trend
              Row(
                children: [
                  Icon(
                    trendIcon,
                    color: trendColor,
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trendValue,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: trendColor,
                    ),
                  ),
                  if (showTrendLabel && trendLabel != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      trendLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingChart(bool isDark, CurrencyProvider currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spending Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDateFilter,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(_totalSpent),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(
                      'Total spent',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Chart Area
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: SpendingChartPainter(
                  isDark: isDark,
                  primaryColor: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // X-Axis Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('W1', style: TextStyle(fontSize: 12)),
                Text('W2', style: TextStyle(fontSize: 12)),
                Text('W3', style: TextStyle(fontSize: 12)),
                Text('W4', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCategory(bool isDark, CurrencyProvider currency) {
    final segments = _categoryBreakdown
        .map((e) => ChartSegment(
              color: e['color'] as Color,
              percentage: (e['percentage'] as double).clamp(0.0, 1.0),
            ))
        .toList();
    final topLabel = _categoryBreakdown.isNotEmpty ? (_categoryBreakdown.first['label'] as String?) ?? '—' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense by Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 24),
            if (_categoryBreakdown.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(120, 120),
                          painter: DonutChartPainter(segments: segments),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Top',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              Text(
                                topLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in _categoryBreakdown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLegendItem(
                              isDark: isDark,
                              color: e['color'] as Color,
                              label: e['label'] as String,
                              percentage: e['pctLabel'] as String,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required bool isDark,
    required Color color,
    required String label,
    required String percentage,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskAndBudget(bool isDark, CurrencyProvider currency) {
    final taskPct = _taskTotal > 0 ? (_taskDone / _taskTotal).clamp(0.0, 1.0) : 0.0;
    final budgetPct = _totalBudget > 0 ? (_totalSpent / _totalBudget).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Health',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        Text(
                          '$_taskTotal Total Tasks',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _taskTotal > 0 ? '${(taskPct * 100).round()}% Done' : '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 12,
                    child: LinearProgressIndicator(
                      value: _taskTotal > 0 ? taskPct : null,
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTaskLegendItem(
                      isDark: isDark,
                      color: AppColors.success,
                      label: 'Done ($_taskDone)',
                    ),
                    const SizedBox(width: 16),
                    _buildTaskLegendItem(
                      isDark: isDark,
                      color: Colors.transparent,
                      borderColor: isDark ? Colors.white.withOpacity(0.2) : AppColors.lightBorder,
                      label: 'Pending ($_pendingTasks)',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budget Utilized',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : AppColors.lightBorder,
                        ),
                      ),
                      child: Text(
                        '${currency.format(_totalSpent)} / ${currency.format(_totalBudget)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth * budgetPct.clamp(0.0, 1.0);
                    return Stack(
                      children: [
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        SizedBox(
                          width: w,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0%',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      _totalBudget > 0 ? '${(budgetPct * 100).round()}%' : '—',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(
                      '100%',
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
        ],
      ),
    );
  }

  Widget _buildTaskLegendItem({
    required bool isDark,
    required Color color,
    Color? borderColor,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsAlert(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface.withOpacity(0.4) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insight Available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Travel expenses are currently ',
                        ),
                        TextSpan(
                          text: '15% higher',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        const TextSpan(
                          text: ' than projected for this milestone. Consider reviewing upcoming trip approvals.',
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
    );
  }
}

// Custom Painter for Spending Chart
class SpendingChartPainter extends CustomPainter {
  final bool isDark;
  final Color primaryColor;

  SpendingChartPainter({required this.isDark, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw area fill
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.13, size.height * 0.7,
        size.width * 0.2, size.height * 0.3,
        size.width * 0.33, size.height * 0.3,
      )
      ..cubicTo(
        size.width * 0.46, size.height * 0.3,
        size.width * 0.53, size.height * 0.8,
        size.width * 0.66, size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.79, size.height * 0.4,
        size.width * 0.86, size.height * 0.2,
        size.width, size.height * 0.1,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, areaPaint);

    // Draw line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = primaryColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final linePath = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.13, size.height * 0.7,
        size.width * 0.2, size.height * 0.3,
        size.width * 0.33, size.height * 0.3,
      )
      ..cubicTo(
        size.width * 0.46, size.height * 0.3,
        size.width * 0.53, size.height * 0.8,
        size.width * 0.66, size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.79, size.height * 0.4,
        size.width * 0.86, size.height * 0.2,
        size.width, size.height * 0.1,
      );

    canvas.drawPath(linePath, linePaint);

    // Draw points
    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.33, size.height * 0.3), 4, pointPaint);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.6), 4, pointPaint);

    // Draw border around points
    final borderPaint = Paint()
      ..color = isDark ? AppColors.darkCard : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(size.width * 0.33, size.height * 0.3), 4, borderPaint);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.6), 4, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Chart Segment for Donut
class ChartSegment {
  final Color color;
  final double percentage;

  ChartSegment({required this.color, required this.percentage});
}

// Custom Painter for Donut Chart
class DonutChartPainter extends CustomPainter {
  final List<ChartSegment> segments;

  DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = -90 * (3.14159 / 180); // Start from top

    for (final segment in segments) {
      final sweepAngle = 360 * segment.percentage * (3.14159 / 180);

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}