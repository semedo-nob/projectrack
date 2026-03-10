// lib/ui/projects/daily_logs_history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class DailyLogsHistoryScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const DailyLogsHistoryScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<DailyLogsHistoryScreen> createState() => _DailyLogsHistoryScreenState();
}

class _DailyLogsHistoryScreenState extends State<DailyLogsHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _dailyLogs = [];
  Map<String, dynamic>? _todayLog;
  DateTime? _projectStartDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
  }

  Future<void> _loadLogs() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final expenses = await db.getExpensesByProject(widget.projectId);
    final project = await db.getCurrentProjectOrNull(widget.projectId);
    if (!mounted) return;
    _projectStartDate = project?.startDate;
    final grouped = <String, List<Expense>>{};
    for (final e in expenses) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final todayKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final list = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      final date = entry.key;
      final items = entry.value;
      final total = items.fold<double>(0, (s, e) => s + e.amount);
      final dayNum = _projectStartDate != null
          ? DateTime.parse('$date').difference(DateTime(_projectStartDate!.year, _projectStartDate!.month, _projectStartDate!.day)).inDays + 1
          : null;
      final dayLabel = dayNum != null ? 'Day $dayNum' : date;
      final dateFormatted = _formatDateKey(date);
      final log = {
        'day': dayLabel,
        'date': dateFormatted,
        'dateKey': date,
        'items': items.length,
        'total': total,
        'locked': date != todayKey,
      };
      if (date == todayKey) {
        _todayLog = log;
      } else {
        list.add(log);
      }
    }
    list.sort((a, b) => (b['dateKey'] as String).compareTo(a['dateKey'] as String));
    setState(() {
      _dailyLogs = list;
      if (_todayLog == null && grouped.containsKey(todayKey)) {
        final items = grouped[todayKey]!;
        _todayLog = {
          'day': 'Today',
          'date': _formatDateKey(todayKey),
          'items': items.length,
          'total': items.fold<double>(0, (s, e) => s + e.amount),
          'locked': false,
        };
      }
      _loading = false;
    });
  }

  String _formatDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return DateFormat('MMM d, yyyy').format(d);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPastLogs {
    if (_searchQuery.isEmpty) return _dailyLogs;
    final q = _searchQuery.toLowerCase();
    return _dailyLogs.where((log) {
      return (log['day']?.toString().toLowerCase().contains(q) ?? false) ||
          (log['date']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            slivers: [
              // Top App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.9),
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => context.go(AppRoutes.home),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: theme.appBarTheme.foregroundColor,
                      size: 20,
                    ),
                  ),
                ),
                title: GestureDetector(
                  onTap: () => context.push('/project/${widget.projectId}', extra: widget.projectName),
                  child: Text(
                    'Daily Logs History',
                    style: theme.appBarTheme.titleTextStyle,
                  ),
                ),
                centerTitle: true,
                actions: [
                  const SizedBox(width: 48), // Balance for alignment
                ],
              ),

              // Search Bar
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildSearchBar(isDark, theme),
                ),
              ),

              // Current Log Section
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Log',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _loading
                          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                          : _buildCurrentLogCard(isDark, theme),
                    ],
                  ),
                ),
              ),

              // Past Logs Section
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Header with "Read Only" label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Past Logs',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'READ ONLY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Past Logs List
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_filteredPastLogs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No past logs. Add entries from Daily Material Entry.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        )
                      else
                        ..._filteredPastLogs.map((log) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPastLogCard(isDark, theme, log),
                        )).toList(),
                    ],
                  ),
                ),
              ),

              // Bottom Spacer
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      ),
      child: Row(
        children: [
          // Search Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: Icon(
              Icons.search_rounded,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              size: 24,
            ),
          ),

          // Search Input
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search logs by date or phase...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLogCard(bool isDark, ThemeData theme) {
    final todayLog = _todayLog;
    final currency = Provider.of<CurrencyProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todayLog != null ? '${todayLog['day']} - Today' : 'Today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  todayLog != null
                      ? '${todayLog['date']} • ${todayLog['items']} items logged'
                      : 'No entries today',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (todayLog != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${currency.format((todayLog['total'] as num).toDouble())} Total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => context.push('/project/${widget.projectId}/material-entry', extra: widget.projectName),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(70, 40),
              ),
              child: Text(
                todayLog != null ? 'Edit' : 'Add',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastLogCard(bool isDark, ThemeData theme, Map<String, dynamic> log) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withOpacity(0.6) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['day'].toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log['date']} • ${log['items']} items',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Provider.of<CurrencyProvider>(context).format((log['total'] as num).toDouble()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),

          // Locked & View Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Locked indicator
              Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'LOCKED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // View Button
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () {
                    // Show read-only view of past log
                    _showReadOnlyLogDialog(log);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(70, 32),
                  ),
                  child: Text(
                    'View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReadOnlyLogDialog(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: Text(
          log['day'],
          style: Theme.of(context).dialogTheme.titleTextStyle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${log['date']}',
              style: Theme.of(context).dialogTheme.contentTextStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Items: ${log['items']}',
              style: Theme.of(context).dialogTheme.contentTextStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${Provider.of<CurrencyProvider>(context).format((log['total'] as num).toDouble())}',
              style: Theme.of(context).dialogTheme.contentTextStyle,
            ),
            const SizedBox(height: 16),
            Text(
              'This log is locked and cannot be edited.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}