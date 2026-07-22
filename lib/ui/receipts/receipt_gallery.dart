// lib/ui/expenses/receipt_gallery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../routes/app_routes.dart';

class ReceiptGalleryScreen extends StatefulWidget {
  final String? projectId;
  final String? projectName;

  const ReceiptGalleryScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  State<ReceiptGalleryScreen> createState() => _ReceiptGalleryScreenState();
}

class _ReceiptGalleryScreenState extends State<ReceiptGalleryScreen> {
  List<Expense> _receipts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter states
  String _selectedFilter = 'All';
  String? _selectedProjectFilter;
  String? _selectedMonthFilter;

  // Available projects for filtering
  List<String> _availableProjects = [];
  Map<String, String> _projectNames = {};
  List<String> _monthOptions = ['All'];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);

      // If projectId is provided, load only that project's receipts
      List<Expense> allExpenses;
      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        allExpenses = await db.getExpensesByProject(widget.projectId!);
      } else {
        allExpenses = await db.getAllExpenses();
      }

      // Filter only expenses with receipt images
      final receiptExpenses = allExpenses.where((e) => e.hasReceipt).toList();

      // Extract unique projects for filter
      final projects = receiptExpenses.map((e) => e.projectId).toSet().toList();
      final allProjects = await db.getAllProjects();
      final projectNames = {
        for (final project in allProjects) project.id: project.name,
      };
      final monthOptions = _buildMonthOptions(receiptExpenses);

      if (mounted) {
        setState(() {
          _receipts = receiptExpenses;
          _availableProjects = projects;
          _projectNames = projectNames;
          _monthOptions = monthOptions;
          if (_selectedMonthFilter != null &&
              !_monthOptions.contains(_selectedMonthFilter)) {
            _selectedMonthFilter = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load receipts: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<String> _buildMonthOptions(List<Expense> receipts) {
    final months = receipts
        .map((receipt) => DateFormat('MMM yyyy').format(receipt.date))
        .toSet()
        .toList()
      ..sort((a, b) {
        final aDate = DateFormat('MMM yyyy').parse(a);
        final bDate = DateFormat('MMM yyyy').parse(b);
        return bDate.compareTo(aDate);
      });
    return ['All', ...months];
  }

  List<Expense> get _filteredReceipts {
    return _receipts.where((receipt) {
      // Filter by project
      if (_selectedProjectFilter != null &&
          _selectedProjectFilter != 'All Projects' &&
          receipt.projectId != _selectedProjectFilter) {
        return false;
      }

      // Filter by month
      if (_selectedMonthFilter != null &&
          _selectedMonthFilter != 'All') {
        final receiptMonth = DateFormat('MMM yyyy').format(receipt.date);
        if (receiptMonth != _selectedMonthFilter) {
          return false;
        }
      }

      return true;
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
                backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.8),
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => context.go(AppRoutes.home),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.appBarTheme.foregroundColor,
                      size: 20,
                    ),
                  ),
                ),
                title: Text(
                  widget.projectId == null ? 'Receipt Gallery' : '${widget.projectName} Receipts',
                  style: theme.appBarTheme.titleTextStyle,
                ),
                centerTitle: true,
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: theme.appBarTheme.foregroundColor,
                        size: 20,
                      ),
                      onPressed: _loadReceipts,
                    ),
                  ),
                ],
              ),

              // Filter Chips Section
              if (_receipts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Project filter chip
                          _buildFilterChip(
                            label: _selectedProjectFilter ?? 'All Projects',
                            isSelected: false,
                            isDark: isDark,
                            showDropdown: true,
                            onTap: () => _showProjectFilterDialog(),
                          ),
                          const SizedBox(width: 12),

                          // Month filter chip
                          _buildFilterChip(
                            label: _selectedMonthFilter ?? 'Month',
                            isSelected: false,
                            isDark: isDark,
                            showDropdown: true,
                            onTap: () => _showMonthFilterDialog(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Receipt Grid or Empty State
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading receipts',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReceipts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredReceipts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
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
                            'No receipts found',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan your first receipt to get started',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (widget.projectId != null && widget.projectId!.isNotEmpty) {
                                context.push(
                                  AppRoutes.projectReceiptOcr.replaceFirst(':id', widget.projectId!),
                                  extra: {'projectName': widget.projectName},
                                );
                              } else {
                                context.push(AppRoutes.receiptOcr);
                              }
                            },
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Scan Receipt'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                // Receipt Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final receipt = _filteredReceipts[index];
                          return _buildReceiptCard(isDark, receipt);
                        },
                        childCount: _filteredReceipts.length,
                      ),
                    ),
                  ),

              // Bottom Spacer (for FAB)
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // Floating Action Button
          if (!_isLoading)
            Positioned(
              bottom: 24,
              right: 16,
              child: _buildFAB(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required bool showDropdown,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.black
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isSelected
                    ? Colors.black
                    : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProjectFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter by Project',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All Projects'),
              onTap: () {
                setState(() {
                  _selectedProjectFilter = null;
                });
                Navigator.pop(context);
              },
            ),
            ..._availableProjects.map((projectId) {
              return ListTile(
                title: Text(_projectNames[projectId] ?? 'Project $projectId'),
                onTap: () {
                  setState(() {
                    _selectedProjectFilter = projectId;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showMonthFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter by Month',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._monthOptions.map((month) {
              return ListTile(
                title: Text(month),
                onTap: () {
                  setState(() {
                    _selectedMonthFilter = month == 'All' ? null : month;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(bool isDark, Expense receipt) {
    return GestureDetector(
      onTap: () {
        // Navigate to receipt detail
        context.push('/receipt/${receipt.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Receipt Image
              if (receipt.receiptImage != null && File(receipt.receiptImage!).existsSync())
                Image.file(
                  File(receipt.receiptImage!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder(isDark, receipt);
                  },
                )
              else
                _buildPlaceholder(isDark, receipt),

              // Gradient Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Receipt Status
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: receipt.status.color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        receipt.status.icon,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        receipt.status.displayName,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Date, Merchant, and Amount
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.formattedDate,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        receipt.merchant,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        receipt.formattedAmount,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark, Expense receipt) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_rounded,
              size: 32,
              color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              receipt.merchant,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return FloatingActionButton(
      onPressed: () {
        if (widget.projectId != null && widget.projectId!.isNotEmpty) {
          context.push(
            AppRoutes.projectReceiptOcr.replaceFirst(':id', widget.projectId!),
            extra: {'projectName': widget.projectName},
          );
        } else {
          context.push(AppRoutes.receiptOcr);
        }
      },
      backgroundColor: AppColors.primary,
      child: const Icon(
        Icons.add_rounded,
        color: Colors.black,
      ),
    );
  }

}