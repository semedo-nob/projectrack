// lib/ui/projects/create_project_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../themes/app_colors.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _tagsController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedStatus = 'Planning';
  String _selectedCategory = 'General';
  bool _isLoading = false;

  static const List<String> _categoryOptions = [
    'General',
    'Development',
    'Marketing',
    'Construction',
    'Events',
    'Other',
  ];

  final List<Map<String, dynamic>> _statusOptions = [
    {'label': 'Planning', 'icon': Icons.edit_note_rounded},
    {'label': 'Active', 'icon': Icons.trending_up_rounded},
    {'label': 'On Hold', 'icon': Icons.pause_circle_rounded},
    {'label': 'Done', 'icon': Icons.check_circle_rounded},
  ];

  @override
  void dispose() {
    _projectNameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: isDark ? AppColors.darkSurface : Colors.white,
              onSurface: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleCreateProject() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _projectNameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a project name'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final startDate = _startDate ?? DateTime.now();
    final budget =
        double.tryParse(_budgetController.text.trim().replaceAll(',', '')) ??
        0.0;
    final projectId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final tags = _parseTags();

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null && db.activeUserId != uid) {
      db.setActiveUserId(uid);
    }
    final ok = await db.createProject(
      id: projectId,
      name: name,
      description: description.isNotEmpty ? description : name,
      startDate: startDate,
      endDate: _endDate,
      budget: budget,
      status: _selectedStatus,
      category: _selectedCategory,
      imageUrl: '',
      tags: tags,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(db.error ?? 'Failed to create project'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Project created. Add your first log entry.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
    context.go(AppRoutes.home);
    context.push('/project/$projectId/material-entry', extra: name);
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
          // Main Scrollable Content
          CustomScrollView(
            slivers: [
              // Top App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(
                  0.9,
                ),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.appBarTheme.foregroundColor,
                      size: 28,
                    ),
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ),
                title: Text(
                  'New Project',
                  style: theme.appBarTheme.titleTextStyle,
                ),
                centerTitle: true,
                actions: [
                  const SizedBox(width: 48), // Spacer for balance
                ],
              ),

              // Form Content
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Project Name Field
                        _buildProjectNameField(isDark, theme),

                        const SizedBox(height: 24),

                        // Description Field
                        _buildDescriptionField(isDark, theme),

                        const SizedBox(height: 24),

                        // Date Fields Grid
                        _buildDateFields(isDark, theme),

                        const SizedBox(height: 24),

                        // Budget Field
                        _buildBudgetField(isDark, theme),

                        const SizedBox(height: 24),

                        // Status Selector
                        _buildStatusSelector(isDark, theme),

                        const SizedBox(height: 24),

                        // Category Selector
                        _buildCategoryField(isDark, theme),

                        const SizedBox(height: 24),

                        _buildTagField(isDark, theme),

                        const SizedBox(height: 100), // Space for bottom button
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Fixed Bottom Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomButton(isDark, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTagField(bool isDark, ThemeData theme) {
    final previewTags = _parseTags();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tagsController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'client, urgent, interior',
            helperText: 'Separate tags with commas',
            prefixIcon: const Icon(Icons.sell_outlined),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (previewTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: previewTags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    avatar: const Icon(Icons.tag, size: 16),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildProjectNameField(bool isDark, ThemeData theme) {
    return Focus(
      onFocusChange: (hasFocus) {
        // Optional: Add animation when focused
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'PROJECT NAME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()..scale(isFocused ? 1.01 : 1.0),
                child: TextFormField(
                  controller: _projectNameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a project name';
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Q3 Marketing Campaign',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    suffixIcon: isFocused
                        ? Icon(
                            Icons.edit_rounded,
                            color: AppColors.primary,
                            size: 24,
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkCard
                        : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDescriptionField(bool isDark, ThemeData theme) {
    return Focus(
      onFocusChange: (hasFocus) {
        // Optional: Add animation when focused
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()..scale(isFocused ? 1.01 : 1.0),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  validator: (value) => null,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Briefly describe the goals and requirements...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkCard
                        : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(24),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateFields(bool isDark, ThemeData theme) {
    return Row(
      children: [
        // Start Date
        Expanded(
          child: _buildDateField(
            isDark: isDark,
            label: 'START DATE',
            date: _startDate,
            onTap: () => _selectDate(context, true),
          ),
        ),
        const SizedBox(width: 16),

        // End Date
        Expanded(
          child: _buildDateField(
            isDark: isDark,
            label: 'END DATE',
            date: _endDate,
            onTap: () => _selectDate(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required bool isDark,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                const SizedBox(width: 12),
                Text(
                  date == null ? 'Select date' : _formatDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    color: date == null
                        ? (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary)
                        : (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetField(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'BUDGET (OPTIONAL)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Center(
                  child: Consumer<CurrencyProvider>(
                    builder: (_, currency, _) => Text(
                      currency.symbol,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            'STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _statusOptions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = _statusOptions[index];
              final isSelected = _selectedStatus == option['label'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStatus = option['label'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.darkCard
                              : AppColors.lightBackground),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        option['icon'],
                        color: isSelected
                            ? Colors.black
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option['label'],
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.black
                              : (isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'CATEGORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: theme.iconTheme.color,
              ),
              items: _categoryOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? AppColors.darkBackground : AppColors.lightBackground)
                .withOpacity(0),
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
          ],
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCreateProject,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: AppColors.primary.withOpacity(0.3),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.save_rounded),
                      SizedBox(width: 12),
                      Text(
                        'Create Project',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
