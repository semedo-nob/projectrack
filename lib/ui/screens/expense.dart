// lib/ui/expenses/categorized_expenses_screen.dart
import 'dart:io';
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
import '../widgets/enterprise_ui.dart';

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
  List<Project> _allProjects = [];
  double _totalAmount = 0;
  int _pendingReceiptsCount = 0;
  int _verifiedCount = 0;
  bool _loading = true;
  String? _selectedCategoryFilter;
  String? _selectedDateFilter;

  // Filter options
  final List<String> _categoryFilters = ['All', 'Materials', 'Labor', 'Equipment', 'Travel', 'Other'];
  final List<String> _dateFilters = ['All', 'Today', 'Yesterday', 'This Week', 'This Month', 'Last Month'];

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
    setState(() => _loading = true);

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);

      // Load all projects for reference
      _allProjects = await db.getAllProjects();

      final allExpenses = <Expense>[];
      for (var p in _allProjects) {
        final list = await db.getExpensesByProject(p.id);
        for (var e in list) {
          allExpenses.add(e);
        }
      }

      // Filter by project if not 'default'
      List<Expense> expenses = widget.projectId == 'default' || widget.projectId.isEmpty
          ? allExpenses
          : allExpenses.where((e) => e.projectId == widget.projectId).toList();

      // Sort by date (newest first)
      expenses.sort((a, b) => b.date.compareTo(a.date));

      // Group by merchant
      final grouped = <String, List<Expense>>{};
      for (var e in expenses) {
        final key = e.merchant.trim().isEmpty ? 'Other' : e.merchant.trim();
        grouped.putIfAbsent(key, () => []).add(e);
      }

      double total = 0;
      int pending = 0;
      int verified = 0;
      final categories = <Map<String, dynamic>>[];

      for (var entry in grouped.entries) {
        final merchant = entry.key;
        final items = entry.value;
        const icon = Icons.receipt_long_rounded;
        const iconColor = AppColors.primary;
        final iconBgColor = AppColors.primary.withOpacity(0.08);

        final itemMaps = items.map((e) {
          final hasReceipt = e.hasReceipt;
          if (!hasReceipt) pending++;
          if (e.isVerified) verified++;
          total += e.amount;

          // Find project name
          final project = _allProjects.firstWhere(
                (p) => p.id == e.projectId,
            orElse: () => Project(
              id: e.projectId,
              name: 'Unknown Project',
              description: '',
              startDate: DateTime.now(),
              budget: 0,
              spent: 0,
              status: '',
              category: '',
              tags: [],
              progress: 0,
              imageUrl: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          return {
            'expense': e,
            'projectName': project.name,
            'projectId': e.projectId,
            'name': e.notes?.isNotEmpty == true ? e.notes! : e.merchant,
            'status': e.status,
            'statusColor': e.status.color,
            'statusIcon': e.status.icon,
            'date': DateFormat('MMM d, yyyy').format(e.date),
            'dateTime': e.date,
            'amount': e.amount,
            'type': e.category.displayName,
            'categoryColor': e.category.color,
            'categoryIcon': e.category.icon,
            'receiptMissing': !hasReceipt,
            'hasReceipt': hasReceipt,
            'receiptImagePath': e.receiptImage,
          };
        }).toList();

        // Sort items by date (newest first)
        itemMaps.sort((a, b) => (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime));

        categories.add({
          'merchant': merchant,
          'icon': icon,
          'iconColor': iconColor,
          'iconBgColor': iconBgColor,
          'itemCount': itemMaps.length,
          'items': itemMaps,
        });
      }

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _totalAmount = total;
        _pendingReceiptsCount = pending;
        _verifiedCount = verified;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading expenses: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.isEmpty && _selectedCategoryFilter == null && _selectedDateFilter == null) {
      return _categories;
    }

    return _categories.map((category) {
      final filteredItems = (category['items'] as List).where((item) {
        final expense = item['expense'] as Expense;
        final matchesSearch = _searchQuery.isEmpty ||
            item['name'].toString().toLowerCase().contains(_searchQuery) ||
            expense.merchant.toLowerCase().contains(_searchQuery) ||
            expense.category.displayName.toLowerCase().contains(_searchQuery);

        final matchesCategory = _selectedCategoryFilter == null ||
            _selectedCategoryFilter == 'All' ||
            expense.category.displayName.contains(_selectedCategoryFilter!);

        final matchesDate = _selectedDateFilter == null ||
            _selectedDateFilter == 'All' ||
            _matchesDateFilter(expense.date, _selectedDateFilter!);

        return matchesSearch && matchesCategory && matchesDate;
      }).toList();

      if (filteredItems.isEmpty) return null;

      return {
        ...category,
        'items': filteredItems,
        'itemCount': filteredItems.length,
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  bool _matchesDateFilter(DateTime date, String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0);

    switch (filter) {
      case 'Today':
        return date.isAfter(today.subtract(const Duration(days: 1)));
      case 'Yesterday':
        return date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day;
      case 'This Week':
        return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
      case 'This Month':
        return date.isAfter(startOfMonth.subtract(const Duration(days: 1)));
      case 'Last Month':
        return date.isAfter(startOfLastMonth.subtract(const Duration(days: 1))) &&
            date.isBefore(endOfLastMonth.add(const Duration(days: 1)));
      default:
        return true;
    }
  }

  void _showReceiptImage(String? imagePath) {
    if (imagePath == null || !File(imagePath).existsSync()) {
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

  void _showExpenseDetails(Map<String, dynamic> item) {
    final expense = item['expense'] as Expense;

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
          return Container(
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
                    'Expense Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Amount Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      Provider.of<CurrencyProvider>(context, listen: false).format(expense.amount),
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? AppColors.darkText
                                            : AppColors.lightText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: expense.status.color.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                expense.status.icon,
                                color: expense.status.color,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Details Grid
                      _buildDetailRow(
                        icon: Icons.storefront_rounded,
                        label: 'Merchant',
                        value: expense.merchant,
                        color: AppColors.primary,
                      ),
                      _buildDetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: DateFormat('MMMM d, yyyy').format(expense.date),
                        color: AppColors.info,
                      ),
                      _buildDetailRow(
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: expense.category.displayName,
                        color: expense.category.color,
                      ),
                      _buildDetailRow(
                        icon: Icons.folder_rounded,
                        label: 'Project',
                        value: item['projectName'] as String,
                        color: AppColors.secondary,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/project/${expense.projectId}');
                        },
                      ),

                      if (expense.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkCard
                                : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expense.notes!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Receipt Image Section
                      if (expense.hasReceipt) ...[
                        Text(
                          'Receipt Image',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showReceiptImage(expense.receiptImage),
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              image: DecorationImage(
                                image: FileImage(File(expense.receiptImage!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                const Icon(
                                  Icons.zoom_in_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                side: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.push('/receipt/${expense.id}');
                              },
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('View Full Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
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
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: onTap != null
              ? Border.all(color: color.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
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
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);
    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        color: AppColors.primary,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        child: CustomScrollView(
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              toolbarHeight: kToolbarHeight,
              floating: true,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: EnterpriseUi.appBarBg(isDark),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                onPressed: () => context.go(AppRoutes.home),
              ),
              title: Text(
                widget.projectId == 'default' ? 'Expenses' : widget.projectName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
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
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 20,
                  ),
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  onSelected: (value) {
                    if (value.startsWith('category:')) {
                      setState(() => _selectedCategoryFilter = value.substring(9));
                    } else if (value.startsWith('date:')) {
                      setState(() => _selectedDateFilter = value.substring(5));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('CATEGORY FILTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ..._categoryFilters.map((filter) => PopupMenuItem(
                      value: 'category:$filter',
                      child: Row(
                        children: [
                          if (_selectedCategoryFilter == filter)
                            Icon(Icons.check, size: 16, color: AppColors.primary),
                          const SizedBox(width: 24),
                          Text(filter),
                        ],
                      ),
                    )),
                    const PopupMenuItem(
                      enabled: false,
                      child: Divider(),
                    ),
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('DATE FILTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ..._dateFilters.map((filter) => PopupMenuItem(
                      value: 'date:$filter',
                      child: Row(
                        children: [
                          if (_selectedDateFilter == filter)
                            Icon(Icons.check, size: 16, color: AppColors.primary),
                          const SizedBox(width: 24),
                          Text(filter),
                        ],
                      ),
                    )),
                    const PopupMenuItem(
                      enabled: false,
                      child: Divider(),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all_rounded, size: 16, color: AppColors.warning),
                          const SizedBox(width: 24),
                          const Text('Clear Filters'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(EnterpriseUi.padH),
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
                              value: '$_pendingReceiptsCount',
                              subtitle: '$_verifiedCount verified',
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
                              : 'No expenses match your filters',
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
                              ? 'Add entries from a project\'s Daily Material Entry or scan receipts.'
                              : 'Try adjusting your search or filters.',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedCategoryFilter != null || _selectedDateFilter != null) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategoryFilter = null;
                                _selectedDateFilter = null;
                              });
                            },
                            icon: const Icon(Icons.clear_all_rounded),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: EnterpriseUi.padH),
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
          hintText: 'Search merchants, notes, category…',
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.clear_rounded,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              size: 18,
            ),
            onPressed: () => _searchController.clear(),
          )
              : null,
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
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
          ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Expanded(
                child: Text(
                  category['merchant'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length} Item${items.length != 1 ? 's' : ''}',
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
    final expense = item['expense'] as Expense;
    final isMissing = expense.isMissingReceipt;
    final hasReceipt = expense.hasReceipt;

    return GestureDetector(
      onTap: () => _showExpenseDetails(item),
      onLongPress: hasReceipt ? () => _showReceiptImage(expense.receiptImage) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMissing
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isMissing ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: expense.status.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: expense.status.color.withOpacity(0.3),
                ),
              ),
              child: Icon(
                expense.status.icon,
                color: expense.status.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expense.merchant,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, yyyy').format(expense.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            expense.category.icon,
                            size: 10,
                            color: expense.category.color,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              expense.category.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: expense.category.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      currency.format(expense.amount),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasReceipt)
                    const Icon(
                      Icons.image_rounded,
                      size: 12,
                      color: AppColors.success,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'No receipt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
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