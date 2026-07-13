// lib/ui/projects/project_overview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/service/export_service.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
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

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen>
    with SingleTickerProviderStateMixin {
  Project? _project;
  List<Expense> _recentExpenses = [];
  List<Map<String, dynamic>> _recentLogs = [];
  bool _loading = true;
  String? _loadError;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjectData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectData() async {
    if (widget.projectId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Invalid project';
      });
      return;
    }

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);

      // Load project details
      await db.loadProject(widget.projectId);
      final project = db.currentProject;

      if (project == null) {
        setState(() {
          _loading = false;
          _loadError = 'Project not found';
        });
        return;
      }

      // Load recent expenses
      final expenses = await db.getExpensesByProject(widget.projectId);
      expenses.sort((a, b) => b.date.compareTo(a.date));
      _recentExpenses = expenses.take(5).toList();

      // Group expenses by day for logs
      final grouped = <String, List<Expense>>{};
      for (final e in expenses) {
        final key = DateFormat('yyyy-MM-dd').format(e.date);
        grouped.putIfAbsent(key, () => []).add(e);
      }

      // Create log entries
      final logs = grouped.entries.map((entry) {
        final date = DateTime.parse(entry.key);
        final total = entry.value.fold<double>(0, (sum, e) => sum + e.amount);
        final hasReceipt = entry.value.any((e) => e.hasReceipt);
        return {
          'date': date,
          'dateKey': entry.key,
          'items': entry.value.length,
          'total': total,
          'hasReceipt': hasReceipt,
          'expenses': entry.value,
        };
      }).toList();

      logs.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );
      _recentLogs = logs.take(3).toList();

      if (!mounted) return;
      setState(() {
        _project = project;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load project: $e';
      });
    }
  }

  Future<void> _editProjectTags(Project project) async {
    final controller = TextEditingController(text: project.tags.join(', '));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Tags'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'client, urgent, interior',
            helperText: 'Separate tags with commas',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final tags =
                  controller.text
                      .split(',')
                      .map((tag) => tag.trim())
                      .where((tag) => tag.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
              final db = Provider.of<DriftDatabaseProvider>(
                context,
                listen: false,
              );
              final ok = await db.updateProject(id: project.id, tags: tags);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (ok) {
                await _loadProjectData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project tags updated'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportProjectSummary(Project project) async {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    final savedName = await ExportService.instance.exportProjectSummaryPdf(
      project: project,
      expenses: _recentExpenses,
      currencyLabel: currency.symbol,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $savedName'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final currency = Provider.of<CurrencyProvider>(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading project…',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadError != null || _project == null) {
      return _buildErrorScreen(isDark);
    }

    final project = _project!;
    final projectName = project.name;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Custom App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor:
                  (isDark ? AppColors.darkBackground : Colors.white)
                      .withOpacity(0.9),
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.black,
                    size: 20,
                  ),
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ),
              title: Text(
                projectName,
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
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 20,
                    ),
                    onPressed: () => _showProjectOptions(context, project),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.transparent,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: isDark
                        ? Colors.white54
                        : Colors.black54,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Expenses'),
                      Tab(text: 'Logs'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Overview Tab
            _buildOverviewTab(isDark, project, currency),

            // Expenses Tab
            _buildExpensesTab(isDark, project, currency),

            // Logs Tab
            _buildLogsTab(isDark, project),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(
          'Project',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_off_rounded,
                size: 64,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                _loadError ?? 'Project not found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Home'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    bool isDark,
    Project project,
    CurrencyProvider currency,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Badge
        Center(child: _buildStatusBadge(isDark, project.status)),

        const SizedBox(height: 24),

        // Financial Card
        _buildFinancialCard(isDark, project, currency),

        const SizedBox(height: 32),

        // Quick Stats
        _buildQuickStats(isDark, project),

        const SizedBox(height: 32),

        // Recent Activity
        _buildRecentActivity(isDark),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildExpensesTab(
    bool isDark,
    Project project,
    CurrencyProvider currency,
  ) {
    if (_recentExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses from Daily Material Entry',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(
                AppRoutes.dailyMaterialEntry.replaceFirst(':id', project.id),
                extra: project.name,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentExpenses.length,
      itemBuilder: (context, index) {
        final expense = _recentExpenses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isDark ? AppColors.darkCard : Colors.white,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: expense.status.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                expense.status.icon,
                color: expense.status.color,
                size: 20,
              ),
            ),
            title: Text(
              expense.merchant,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              DateFormat('MMM d, yyyy').format(expense.date),
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(expense.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (expense.hasReceipt)
                  Icon(Icons.image_rounded, size: 16, color: AppColors.success),
              ],
            ),
            onTap: () => _showExpenseDetails(expense),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab(bool isDark, Project project) {
    if (_recentLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No logs yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding a material entry',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(
                AppRoutes.dailyMaterialEntry.replaceFirst(':id', project.id),
                extra: project.name,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentLogs.length + 1, // +1 for "View All" button
      itemBuilder: (context, index) {
        if (index == _recentLogs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: () => context.push(
                  AppRoutes.dailyLogsHistory.replaceFirst(':id', project.id),
                  extra: project.name,
                ),
                icon: const Icon(Icons.history_rounded),
                label: const Text('View All Logs'),
              ),
            ),
          );
        }

        final log = _recentLogs[index];
        final date = log['date'] as DateTime;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isDark ? AppColors.darkCard : Colors.white,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              DateFormat('EEEE, MMM d').format(date),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              '${log['items']} item${log['items'] != 1 ? 's' : ''}',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (log['hasReceipt'] as bool)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.receipt_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white54 : Colors.grey.shade400,
                ),
              ],
            ),
            onTap: () => _showLogDetails(date, log['expenses']),
          ),
        );
      },
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
      case 'Planning':
        return AppColors.info;
      default:
        return AppColors.primaryMuted;
    }
  }

  Widget _buildStatusBadge(bool isDark, String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            status,
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

  Widget _buildFinancialCard(
    bool isDark,
    Project project,
    CurrencyProvider currency,
  ) {
    final spent = project.spent;
    final budget = project.budget;
    final remaining = (budget - spent).clamp(0.0, double.infinity);
    final progress = project.progress.clamp(0.0, 1.0);
    final spentPercent = budget > 0 ? (spent / budget * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
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
                    'TOTAL SPENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(spent),
                    style: const TextStyle(
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
            'Budget: ${currency.format(budget)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          Text(
            'Remaining: ${currency.format(remaining)}',
            style: const TextStyle(
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
                  '${(progress * 100).toInt()}%',
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
              value: progress,
              backgroundColor: Colors.black.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 12),

          // Budget usage indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  spentPercent > 80
                      ? Icons.warning_amber_rounded
                      : Icons.info_rounded,
                  color: spentPercent > 80 ? Colors.black : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spentPercent > 80
                        ? 'You\'ve used $spentPercent% of your budget. Consider reviewing expenses.'
                        : '$spentPercent% of budget used. You\'re on track.',
                    style: const TextStyle(color: Colors.black, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark, Project project) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  isDark: isDark,
                  icon: Icons.calendar_today_rounded,
                  value: DateFormat('MMM d, yyyy').format(project.startDate),
                  label: 'Started',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  isDark: isDark,
                  icon: Icons.event_rounded,
                  value: project.endDate != null
                      ? DateFormat('MMM d, yyyy').format(project.endDate!)
                      : 'Not set',
                  label: 'End Date',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  isDark: isDark,
                  icon: Icons.category_rounded,
                  value: project.category,
                  label: 'Category',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  isDark: isDark,
                  icon: Icons.receipt_long_rounded,
                  value: '${_recentExpenses.length}',
                  label: 'Expenses',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required bool isDark,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => context.push(
                  AppRoutes.dailyLogsHistory.replaceFirst(
                    ':id',
                    widget.projectId,
                  ),
                  extra: widget.projectName,
                ),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  isDark: isDark,
                  icon: Icons.add_rounded,
                  color: AppColors.primary,
                  label: 'Add Entry',
                  onTap: () => context.push(
                    AppRoutes.dailyMaterialEntry.replaceFirst(
                      ':id',
                      widget.projectId,
                    ),
                    extra: widget.projectName,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  isDark: isDark,
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.success,
                  label: 'Expenses',
                  onTap: () {
                    _tabController.animateTo(1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  isDark: isDark,
                  icon: Icons.analytics_rounded,
                  color: AppColors.info,
                  label: 'Report',
                  onTap: () => context.push(
                    AppRoutes.projectReports.replaceFirst(
                      ':id',
                      widget.projectId,
                    ),
                    extra: widget.projectName,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  isDark: isDark,
                  icon: Icons.task_alt_rounded,
                  color: AppColors.warning,
                  label: 'Tasks',
                  onTap: () => context.push(
                    AppRoutes.projectTasks.replaceFirst(
                      ':id',
                      widget.projectId,
                    ),
                    extra: widget.projectName,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  isDark: isDark,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.construction,
                  label: 'Inventory',
                  onTap: () => context.push(
                    AppRoutes.projectInventory.replaceFirst(
                      ':id',
                      widget.projectId,
                    ),
                    extra: widget.projectName,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final currency = Provider.of<CurrencyProvider>(context);

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Expense Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Merchant
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.storefront_rounded,
                        label: 'Merchant',
                        value: expense.merchant,
                        color: AppColors.primary,
                      ),

                      // Amount
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.payments_rounded,
                        label: 'Amount',
                        value: currency.format(expense.amount),
                        color: AppColors.success,
                      ),

                      // Date
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: DateFormat('MMMM d, yyyy').format(expense.date),
                        color: AppColors.info,
                      ),

                      // Category
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: expense.category.displayName,
                        color: expense.category.color,
                      ),

                      // Status
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.info_rounded,
                        label: 'Status',
                        value: expense.status.displayName,
                        color: expense.status.color,
                      ),

                      if (expense.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(expense.notes!),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Close'),
                            ),
                          ),
                          if (expense.hasReceipt) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showReceiptImage(expense.receiptImage!);
                                },
                                icon: const Icon(Icons.image_rounded),
                                label: const Text('View Receipt'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReceiptImage(String imagePath) {
    if (!File(imagePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt image not found'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                height: MediaQuery.of(context).size.height * 0.7,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogDetails(DateTime date, List<Expense> expenses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextTertiary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                DateFormat('EEEE, MMMM d, yyyy').format(date),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Expenses list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  final currency = Provider.of<CurrencyProvider>(context);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: expense.status.backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          expense.status.icon,
                          color: expense.status.color,
                          size: 20,
                        ),
                      ),
                      title: Text(expense.merchant),
                      subtitle: Text(expense.category.displayName),
                      trailing: Text(
                        currency.format(expense.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => _showExpenseDetails(expense),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProjectOptions(BuildContext context, Project project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('Manage Tags'),
              onTap: () {
                Navigator.pop(context);
                _editProjectTags(project);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.construction,
              ),
              title: const Text('Material Inventory'),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  AppRoutes.projectInventory.replaceFirst(':id', project.id),
                  extra: project.name,
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.warning,
              ),
              title: const Text('Manage Tasks'),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  AppRoutes.projectTasks.replaceFirst(':id', project.id),
                  extra: project.name,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.info),
              title: const Text('Export & Organize'),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions(project);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.archive_rounded,
                color: AppColors.warning,
              ),
              title: const Text('Archive Project'),
              onTap: () {
                Navigator.pop(context);
                _showArchiveConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text('Delete Project'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(Project project) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Project Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Export as PDF'),
              subtitle: const Text('Project summary report'),
              onTap: () async {
                Navigator.pop(context);
                await _exportProjectSummary(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_rounded, color: AppColors.success),
              title: const Text('Manage Tags'),
              subtitle: const Text('Keep search and cards organized'),
              onTap: () {
                Navigator.pop(context);
                _editProjectTags(project);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Project'),
        content: const Text(
          'Are you sure you want to archive this project? You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final project = _project;
              if (project == null) return;
              final db = Provider.of<DriftDatabaseProvider>(
                this.context,
                listen: false,
              );
              final ok = await db.updateProject(
                id: project.id,
                status: 'On Hold',
              );
              if (!mounted) return;
              if (ok) {
                await _loadProjectData();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Project moved to On Hold'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(db.error ?? 'Failed to archive project'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project? All expenses, tasks, and logs for this project will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final db = Provider.of<DriftDatabaseProvider>(
                context,
                listen: false,
              );
              final ok = await db.deleteProject(widget.projectId);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project deleted'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                context.go(AppRoutes.home);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(db.error ?? 'Could not delete project'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
