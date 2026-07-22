// lib/ui/expenses/receipt_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/service/export_service.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../routes/app_routes.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final String? receiptId;
  final String? projectId;

  const ReceiptDetailScreen({
    super.key,
    this.receiptId,
    this.projectId,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  Expense? _expense;
  bool _isLoading = true;
  String? _errorMessage;
  String? _projectName;

  @override
  void initState() {
    super.initState();
    _loadReceiptData();
  }

  Future<void> _loadReceiptData() async {
    if (widget.receiptId == null) {
      setState(() {
        _errorMessage = 'No receipt ID provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);

      // Load expense data
      await db.loadExpense(widget.receiptId!);
      final expense = db.currentExpense;

      if (expense == null) {
        throw Exception('Receipt not found');
      }

      // Load project name if available
      String? projectName;
      if (expense.projectId.isNotEmpty) {
        await db.loadProject(expense.projectId);
        projectName = db.currentProject?.name;
      }

      if (mounted) {
        setState(() {
          _expense = expense;
          _projectName = projectName;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load receipt: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReceipt() async {
    if (_expense == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final success = await db.deleteExpense(_expense!.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate deletion
      } else {
        throw Exception(db.error ?? 'Failed to delete receipt');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting receipt: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null || _expense == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.appBarTheme.foregroundColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Error'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  'Could not load receipt',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Receipt not found',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final expense = _expense!;

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
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
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
              'Receipt Detail',
              style: theme.appBarTheme.titleTextStyle,
            ),
            centerTitle: true,
            actions: [
              // Edit Button
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
                    Icons.edit_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 20,
                  ),
                  onPressed: () {
                    // Navigate to edit receipt with expense data
                    context.push(
                      AppRoutes.receiptOcr,
                      extra: {
                        'expenseId': expense.id,
                        'projectId': expense.projectId,
                        'merchant': expense.merchant,
                        'amount': expense.amount,
                        'date': expense.date.toIso8601String(),
                        'notes': expense.notes,
                        'imagePath': expense.receiptImage,
                      },
                    );
                  },
                ),
              ),

              // Delete Button
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
                    Icons.delete_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: () {
                    _showDeleteDialog(context);
                  },
                ),
              ),
            ],
          ),

          // Receipt Image
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildReceiptImage(isDark, expense),
            ),
          ),

          // Status Badge and Total Amount
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: expense.status.backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          expense.status.icon,
                          size: 14,
                          color: expense.status.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          expense.status.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: expense.status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        expense.formattedAmount,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'USD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Section Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Expense Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Details List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Merchant
                _buildDetailItem(
                  isDark: isDark,
                  icon: Icons.storefront_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primary,
                  title: expense.merchant,
                  subtitle: 'Merchant',
                ),

                // Date
                _buildDetailItem(
                  isDark: isDark,
                  icon: Icons.calendar_today_rounded,
                  iconColor: isDark ? AppColors.darkText : AppColors.lightText,
                  iconBgColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  title: DateFormat(
                    (expense.date.hour != 0 ||
                            expense.date.minute != 0 ||
                            expense.date.second != 0)
                        ? 'MMMM d, yyyy · h:mm a'
                        : 'MMMM d, yyyy',
                  ).format(expense.date),
                  subtitle: 'Receipt date & time',
                ),

                _buildDetailItem(
                  isDark: isDark,
                  icon: Icons.schedule_rounded,
                  iconColor: isDark ? AppColors.darkText : AppColors.lightText,
                  iconBgColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  title: DateFormat('MMMM d, yyyy · h:mm a').format(expense.createdAt),
                  subtitle: 'Logged into system',
                ),

                // Category
                _buildDetailItem(
                  isDark: isDark,
                  icon: expense.category.icon,
                  iconColor: expense.category.color,
                  iconBgColor: expense.category.color.withOpacity(0.1),
                  title: expense.category.displayName,
                  subtitle: 'Category',
                  showChevron: true,
                  onTap: () {
                    // TODO: Show category selector
                  },
                ),

                // Notes (if available)
                if (expense.notes != null && expense.notes!.isNotEmpty)
                  _buildDetailItem(
                    isDark: isDark,
                    icon: Icons.note_alt_rounded,
                    iconColor: AppColors.info,
                    iconBgColor: AppColors.info.withOpacity(0.1),
                    title: expense.notes!,
                    subtitle: 'Notes',
                    maxLines: 3,
                  ),

                // Project (highlighted)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildDetailItem(
                    isDark: isDark,
                    icon: Icons.folder_rounded,
                    iconColor: AppColors.primary,
                    iconBgColor: AppColors.primary.withOpacity(0.2),
                    title: _projectName ?? 'Project ${expense.projectId}',
                    subtitle: 'Linked Project',
                    titleStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    subtitleColor: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                    trailingIcon: Icons.open_in_new_rounded,
                    trailingIconColor: AppColors.primary,
                    onTap: () {
                      if (expense.projectId.isNotEmpty) {
                        context.push('/project/${expense.projectId}');
                      }
                    },
                  ),
                ),
              ]),
            ),
          ),

          // Footer Actions
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Export Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        _showExportOptions(context, expense);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        shadowColor: AppColors.primary.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share_rounded),
                          SizedBox(width: 8),
                          Text(
                            'Export Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Created/Updated info
                  Center(
                    child: Text(
                      'Added ${DateFormat('MMM d, yyyy').format(expense.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptImage(bool isDark, Expense expense) {
    final hasImage = expense.hasReceipt && File(expense.receiptImage!).existsSync();

    return GestureDetector(
      onTap: hasImage ? () => _showImageZoomDialog(expense) : null,
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: hasImage
            ? ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(expense.receiptImage!),
                fit: BoxFit.cover,
              ),
              // Zoom indicator
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        )
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 64,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'No receipt image',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Receipt was logged manually',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    bool showChevron = false,
    TextStyle? titleStyle,
    Color? subtitleColor,
    IconData? trailingIcon,
    Color? trailingIconColor,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: titleStyle ?? TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: subtitleColor ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
        trailing: trailingIcon != null
            ? Icon(
          trailingIcon,
          color: trailingIconColor ?? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
        )
            : (showChevron
            ? Icon(
          Icons.chevron_right_rounded,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        )
            : null),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text('Are you sure you want to delete this receipt? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReceipt();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextTertiary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Export Receipt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
              ),
              title: const Text('Export as PDF'),
              subtitle: Text('Receipt from ${expense.merchant} - ${expense.formattedAmount}'),
              onTap: () async {
                Navigator.pop(context);
                final savedName = await ExportService.instance.exportReceiptPdf(
                  expense: expense,
                  projectName: _projectName,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved $savedName'),
                    backgroundColor: AppColors.info,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image_rounded, color: AppColors.success),
              ),
              title: const Text('Save Receipt Image'),
              subtitle: const Text('Save original image file'),
              onTap: () async {
                Navigator.pop(context);
                if (expense.receiptImage == null || expense.receiptImage!.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No receipt image available to save'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final savedName = await ExportService.instance.exportReceiptImageCopy(
                  imagePath: expense.receiptImage!,
                  merchant: expense.merchant,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved $savedName'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showImageZoomDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(expense.receiptImage!),
                  fit: BoxFit.contain,
                  height: MediaQuery.of(context).size.height * 0.7,
                ),
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
}
