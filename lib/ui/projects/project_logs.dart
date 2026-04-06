// lib/ui/projects/daily_logs_history_screen.dart
import 'dart:async';

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

class _DailyLogsHistoryScreenState extends State<DailyLogsHistoryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _dailyLogs = [];
  Map<String, dynamic>? _todayLog;
  DateTime? _projectStartDate;
  DateTimeRange? _selectedDateRange;
  bool _loading = true;
  String? _error;

  late TabController _tabController;
  StreamSubscription<List<Expense>>? _expensesSubscription;
  Timer? _expensesDebounce;

  /// Skip redundant rebuilds when Drift re-emits identical expense rows.
  int _lastAppliedExpenseSignature = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRealtime());
  }

  @override
  void dispose() {
    _expensesDebounce?.cancel();
    _expensesSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Cheap fingerprint so we don't re-group + setState when nothing changed.
  int _expenseListSignature(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;
    var h = expenses.length;
    for (final e in expenses) {
      h = Object.hash(h, e.id, e.updatedAt.microsecondsSinceEpoch, e.amount);
    }
    return h;
  }

  void _scheduleApplyExpenses(List<Expense> expenses) {
    final sig = _expenseListSignature(expenses);
    if (sig == _lastAppliedExpenseSignature && !_loading) {
      return;
    }
    _expensesDebounce?.cancel();
    _expensesDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final s = _expenseListSignature(expenses);
      if (s == _lastAppliedExpenseSignature && !_loading) {
        return;
      }
      _lastAppliedExpenseSignature = s;
      _buildLogsFromExpenses(expenses);
    });
  }

  /// Load project once for start date, then subscribe to expense stream for realtime updates.
  Future<void> _initRealtime() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    try {
      await db.loadProject(widget.projectId);
      if (!mounted) return;
      final project = db.currentProject;
      setState(() {
        _projectStartDate = project?.startDate;
      });

      _expensesSubscription = db
          .watchExpensesByProjectStream(widget.projectId)
          .listen(
            (List<Expense> expenses) {
              if (!mounted) return;
              _scheduleApplyExpenses(expenses);
            },
            onError: (Object e) {
              if (!mounted) return;
              setState(() {
                _error = 'Failed to load logs: $e';
                _loading = false;
              });
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load logs: $e';
        _loading = false;
      });
    }
  }

  void _buildLogsFromExpenses(List<Expense> expenses) {
    _todayLog = null;
    final grouped = <String, List<Expense>>{};
    for (final e in expenses) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final list = <Map<String, dynamic>>[];

    for (final entry in grouped.entries) {
      final dateKey = entry.key;
      final date = DateTime.parse(dateKey);
      final items = entry.value;
      final total = items.fold<double>(0, (s, e) => s + e.amount);

      int? dayNum;
      if (_projectStartDate != null) {
        final start = DateTime(
          _projectStartDate!.year,
          _projectStartDate!.month,
          _projectStartDate!.day,
        );
        dayNum = date.difference(start).inDays + 1;
      }

      final dayLabel = dayNum != null ? 'Day $dayNum' : dateKey;
      final dateFormatted = DateFormat('MMM d, yyyy').format(date);

      final log = {
        'day': dayLabel,
        'date': date,
        'dateKey': dateKey,
        'dateFormatted': dateFormatted,
        'items': items.length,
        'total': total,
        'expenses': items,
        'hasReceipts': items.any((e) => e.hasReceipt),
        'verifiedCount': items.where((e) => e.isVerified).length,
        'locked': dateKey != todayKey,
      };

      if (dateKey == todayKey) {
        _todayLog = log;
      } else {
        list.add(log);
      }
    }

    list.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    setState(() {
      _dailyLogs = list;
      _loading = false;
      _error = null;
    });
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  List<Map<String, dynamic>> get _filteredPastLogs {
    return _dailyLogs.where((log) {
      final logDate = log['date'] as DateTime;
      final matchesRange =
          _selectedDateRange == null ||
          (!_isBeforeDay(logDate, _selectedDateRange!.start) &&
              !_isAfterDay(logDate, _selectedDateRange!.end));
      if (!matchesRange) return false;
      if (_searchQuery.isEmpty) return true;
      final day = log['day']?.toString().toLowerCase() ?? '';
      final date = log['dateFormatted']?.toString().toLowerCase() ?? '';
      return day.contains(_searchQuery) || date.contains(_searchQuery);
    }).toList();
  }

  double get _totalSpent {
    return _dailyLogs.fold<double>(
      0,
      (sum, log) => sum + (log['total'] as num).toDouble(),
    );
  }

  int get _totalItems {
    return _dailyLogs.fold<int>(0, (sum, log) => sum + (log['items'] as int));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _initRealtime();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Top App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(
                0.9,
              ),
              elevation: 0,
              leading: GestureDetector(
                onTap: () => context.go(AppRoutes.home),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 20,
                  ),
                ),
              ),
              title: GestureDetector(
                onTap: () => context.push(
                  '/project/${widget.projectId}',
                  extra: widget.projectName,
                ),
                child: Column(
                  children: [
                    Text('Daily Logs', style: theme.appBarTheme.titleTextStyle),
                    Text(
                      widget.projectName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    color: theme.appBarTheme.foregroundColor,
                  ),
                  onPressed: () => _showDateRangePicker(),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: isDark
                          ? Colors.white54
                          : Colors.black54,
                      tabs: const [
                        Tab(text: 'Today'),
                        Tab(text: 'History'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Today Tab
            _buildTodayTab(isDark, theme, currency),

            // History Tab
            _buildHistoryTab(isDark, theme, currency),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab(
    bool isDark,
    ThemeData theme,
    CurrencyProvider currency,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        if (_todayLog != null) ...[
          // Today's Log Card
          _buildTodayLogCard(isDark, theme, currency),

          const SizedBox(height: 24),

          // Quick Stats
          _buildQuickStats(isDark, currency),

          const SizedBox(height: 24),

          // Today's Expenses
          _buildTodayExpenses(isDark, currency),
        ] else ...[
          Center(
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
                  'No entries for today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a material entry to get started',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/project/${widget.projectId}/material-entry',
                    extra: widget.projectName,
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
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryTab(
    bool isDark,
    ThemeData theme,
    CurrencyProvider currency,
  ) {
    return CustomScrollView(
      primary: false,
      cacheExtent: 400,
      slivers: [
        // Summary Stats
        SliverToBoxAdapter(child: _buildHistorySummary(isDark, currency)),

        // Search Bar
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: _buildSearchBar(isDark, theme)),
        ),

        // Past Logs List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_loading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (_filteredPastLogs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _dailyLogs.isEmpty
                            ? 'No past logs found'
                            : 'No logs match your search',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  );
                }

                final log = _filteredPastLogs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RepaintBoundary(
                    child: _buildPastLogCard(isDark, theme, log, currency),
                  ),
                );
              },
              childCount: _loading
                  ? 1
                  : (_filteredPastLogs.isEmpty ? 1 : _filteredPastLogs.length),
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayLogCard(
    bool isDark,
    ThemeData theme,
    CurrencyProvider currency,
  ) {
    final log = _todayLog!;

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text(
                log['dateFormatted'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  log['day'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                value: '${log['items']}',
                label: 'Items',
                color: Colors.black,
              ),
              _buildStat(
                value: currency.format(log['total']),
                label: 'Total',
                color: Colors.black,
              ),
              _buildStat(
                value: '${log['verifiedCount']}',
                label: 'Verified',
                color: Colors.black,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/project/${widget.projectId}/material-entry',
                    extra: widget.projectName,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add More'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLogDetails(log),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildQuickStats(bool isDark, CurrencyProvider currency) {
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
            'Project Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  isDark: isDark,
                  label: 'Total Spent',
                  value: currency.format(_totalSpent),
                  icon: Icons.payments_rounded,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  isDark: isDark,
                  label: 'Total Days',
                  value: '${_dailyLogs.length}',
                  icon: Icons.calendar_today_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  isDark: isDark,
                  label: 'Total Items',
                  value: '$_totalItems',
                  icon: Icons.inventory_2_rounded,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  isDark: isDark,
                  label: 'With Receipts',
                  value:
                      '${_dailyLogs.fold<int>(0, (sum, log) => sum + (log['hasReceipts'] ? 1 : 0))}',
                  icon: Icons.receipt_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayExpenses(bool isDark, CurrencyProvider currency) {
    final expenses = _todayLog!['expenses'] as List<Expense>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Expenses",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.category.displayName,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (expense.quantityWithUnitLabel.isNotEmpty)
                      Text(
                        expense.quantityWithUnitLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  currency.format(expense.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () => _showExpenseDetails(expense),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistorySummary(bool isDark, CurrencyProvider currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHistoryStat(
            isDark: isDark,
            value: '${_dailyLogs.length}',
            label: 'Days',
          ),
          _buildHistoryStat(
            isDark: isDark,
            value: '$_totalItems',
            label: 'Items',
          ),
          _buildHistoryStat(
            isDark: isDark,
            value: currency.format(_totalSpent),
            label: 'Total',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat({
    required bool isDark,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
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

  Widget _buildSearchBar(bool isDark, ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
            child: Icon(
              Icons.search_rounded,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
              size: 24,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search by day or date...',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
                size: 18,
              ),
              onPressed: () => _searchController.clear(),
            ),
        ],
      ),
    );
  }

  Widget _buildPastLogCard(
    bool isDark,
    ThemeData theme,
    Map<String, dynamic> log,
    CurrencyProvider currency,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withOpacity(0.8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogDetails(log),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Date indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('d').format(log['date']),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(log['date']),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['day'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_rounded,
                            size: 12,
                            color: log['hasReceipts']
                                ? AppColors.success
                                : (isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.lightTextTertiary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${log['items']} items',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Locked',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Total and arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(log['total']),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final expenses = log['expenses'] as List<Expense>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
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

                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        log['day'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log['dateFormatted'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Summary
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailStat(
                        label: 'Items',
                        value: '${log['items']}',
                      ),
                      _buildDetailStat(
                        label: 'Total',
                        value: currency.format(log['total']),
                      ),
                      _buildDetailStat(
                        label: 'Verified',
                        value: '${log['verifiedCount']}',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Expenses list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                expense.category.displayName,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              if (expense.quantityWithUnitLabel.isNotEmpty)
                                Text(
                                  expense.quantityWithUnitLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextTertiary,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Text(
                            currency.format(expense.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showExpenseDetails(expense);
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailStat({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  void _showExpenseDetails(Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
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
                    expense.merchant,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),

                // Details
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.payments_rounded,
                        label: 'Amount',
                        value: currency.format(expense.amount),
                      ),
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: DateFormat('MMMM d, yyyy').format(expense.date),
                      ),
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: expense.category.displayName,
                      ),
                      if (expense.quantityWithUnitLabel.isNotEmpty)
                        _buildDetailRow(
                          isDark: isDark,
                          icon: Icons.scale_rounded,
                          label: 'Quantity',
                          value: expense.quantityWithUnitLabel,
                        ),
                      _buildDetailRow(
                        isDark: isDark,
                        icon: Icons.info_rounded,
                        label: 'Status',
                        value: expense.status.displayName,
                      ),
                      if (expense.notes?.isNotEmpty == true)
                        _buildDetailRow(
                          isDark: isDark,
                          icon: Icons.note_alt_rounded,
                          label: 'Notes',
                          value: expense.notes!,
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

  Widget _buildDetailRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16),
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

  bool _isBeforeDay(DateTime value, DateTime other) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).isBefore(DateTime(other.year, other.month, other.day));
  }

  bool _isAfterDay(DateTime value, DateTime other) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).isAfter(DateTime(other.year, other.month, other.day));
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: _projectStartDate ?? DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDateRange = picked);
  }

  void _showDateRangePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: const Text('Select date range'),
              subtitle: Text(
                _selectedDateRange == null
                    ? 'Filter history logs by date'
                    : '${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickDateRange();
              },
            ),
            if (_selectedDateRange != null)
              ListTile(
                leading: const Icon(Icons.filter_alt_off_rounded),
                title: const Text('Clear date filter'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedDateRange = null);
                },
              ),
          ],
        ),
      ),
    );
  }
}
