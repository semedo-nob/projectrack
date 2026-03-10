// lib/ui/expenses/categorized_expenses_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class CategorizedExpensesScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const CategorizedExpensesScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<CategorizedExpensesScreen> createState() => _CategorizedExpensesScreenState();
}

class _CategorizedExpensesScreenState extends State<CategorizedExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _categories = [];
  double _totalAmount = 0;
  int _pendingReceiptsCount = 0;
  bool _loading = true;

  static const List<IconData> _merchantIcons = [
    Icons.store_rounded,
    Icons.local_shipping_rounded,
    Icons.shopping_bag_rounded,
    Icons.receipt_long_rounded,
    Icons.business_rounded,
  ];
  static const List<Color> _merchantColors = [
    AppColors.warning,
    AppColors.info,
    AppColors.secondary,
    AppColors.primary,
    AppColors.success,
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExpenses());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  Future<void> _loadExpenses() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final projects = await db.getAllProjects();
    final allExpenses = <Expense>[];
    for (var p in projects) {
      final list = await db.getExpensesByProject(p.id);
      for (var e in list) {
        allExpenses.add(e);
      }
    }
    // If this screen is for a specific project (not 'default'), filter to that project only
    List<Expense> expenses = widget.projectId == 'default' || widget.projectId.isEmpty
        ? allExpenses
        : allExpenses.where((e) => e.projectId == widget.projectId).toList();
    expenses.sort((a, b) => b.date.compareTo(a.date));

    final grouped = <String, List<Expense>>{};
    for (var e in expenses) {
      final key = e.merchant.trim().isEmpty ? 'Other' : e.merchant.trim();
      grouped.putIfAbsent(key, () => []).add(e);
    }

    double total = 0;
    int pending = 0;
    final categories = <Map<String, dynamic>>[];
    int colorIndex = 0;
    for (var entry in grouped.entries) {
      final merchant = entry.key;
      final items = entry.value;
      final icon = _merchantIcons[colorIndex % _merchantIcons.length];
      final iconColor = _merchantColors[colorIndex % _merchantColors.length];
      colorIndex++;
      final itemMaps = items.map((e) {
        final hasReceipt = e.receiptImage != null && e.receiptImage!.trim().isNotEmpty;
        if (!hasReceipt) pending++;
        total += e.amount;
        return {
          'expense': e,
          'name': (e.notes != null && e.notes!.trim().isNotEmpty) ? e.notes! : e.merchant,
          'status': hasReceipt ? 'verified' : 'missing',
          'date': DateFormat('MMM d').format(e.date),
          'amount': e.amount,
          'type': e.category.displayName,
          'receiptMissing': !hasReceipt,
          'statusText': hasReceipt ? null : 'Missing Receipt',
        };
      }).toList();
      categories.add({
        'merchant': merchant,
        'icon': icon,
        'iconColor': iconColor,
        'iconBgColor': iconColor.withOpacity(0.1),
        'itemCount': itemMaps.length,
        'items': itemMaps,
      });
    }

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _totalAmount = total;
      _pendingReceiptsCount = pending;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    final q = _searchQuery;
    return _categories.where((cat) {
      if (cat['merchant'].toString().toLowerCase().contains(q)) return true;
      for (var item in cat['items'] as List) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        if (name.contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);
    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.appBarTheme.foregroundColor,
                  size: 20,
                ),
              ),
            ),
            title: Text(
              widget.projectId == 'default' ? 'Expenses & Materials' : '${widget.projectName} — Expenses',
              style: theme.appBarTheme.titleTextStyle,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.analytics_rounded,
                  color: theme.appBarTheme.foregroundColor,
                  size: 22,
                ),
                tooltip: 'Reports & Analytics',
                onPressed: () => context.push(AppRoutes.reportsAnalytics),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                width: 40,
                height: 40,
                child: IconButton(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchBar(isDark),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatsCard(
                            isDark: isDark,
                            title: 'TOTAL EXPENSES',
                            value: currency.format(_totalAmount),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            borderColor: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatsCard(
                            isDark: isDark,
                            title: 'PENDING RECEIPTS',
                            value: '$_pendingReceiptsCount Items',
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: SizedBox.shrink(),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _categories.isEmpty
                            ? 'No expenses yet'
                            : 'No expenses match your search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _categories.isEmpty
                            ? 'Add entries from a project\'s Daily Material Entry or expense logs.'
                            : 'Try a different search.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = filtered[index];
                    return _buildCategorySection(context, isDark, category, currency);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 48,
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
          hintText: 'Search merchant or material...',
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required bool isDark,
    required String title,
    required String value,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> category,
    CurrencyProvider currency,
  ) {
    final items = category['items'] as List;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: category['iconBgColor'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      color: category['iconColor'],
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category['merchant'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              Text(
                '${items.length} Items',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (itemIndex) {
            final item = items[itemIndex] as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildExpenseItem(isDark, item, currency),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(bool isDark, Map<String, dynamic> item, CurrencyProvider currency) {
    final isVerified = item['status'] == 'verified';
    final isMissing = item['status'] == 'missing' || item['receiptMissing'] == true;
    final typeStr = item['type']?.toString() ?? '';
    final isMaterial = typeStr.toUpperCase().contains('MATERIAL') || typeStr == 'Materials';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMissing
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isMissing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isVerified
                  ? (isDark ? AppColors.success.withOpacity(0.2) : AppColors.successLight.withOpacity(0.2))
                  : (isDark ? AppColors.warning.withOpacity(0.2) : AppColors.warningLight.withOpacity(0.2)),
              shape: BoxShape.circle,
              border: Border.all(
                color: isVerified
                    ? (isDark ? AppColors.success.withOpacity(0.3) : AppColors.successLight.withOpacity(0.3))
                    : (isDark ? AppColors.warning.withOpacity(0.3) : AppColors.warningLight.withOpacity(0.3)),
              ),
            ),
            child: Icon(
              isVerified ? Icons.check_circle_rounded : Icons.receipt_rounded,
              color: isVerified
                  ? (isDark ? AppColors.success : AppColors.successDark)
                  : (isDark ? AppColors.warning : AppColors.warningDark),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? 'Receipt Verified • ${item['date'] ?? ''}'
                      : (item['statusText']?.toString() ?? (isMissing ? 'Missing Receipt' : 'Awaiting Upload')),
                  style: TextStyle(
                    fontSize: 11,
                    color: isVerified
                        ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                        : (isDark ? AppColors.error : AppColors.error),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format((item['amount'] as num).toDouble()),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMaterial ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  typeStr.isEmpty ? '—' : typeStr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMaterial
                        ? AppColors.primary
                        : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}