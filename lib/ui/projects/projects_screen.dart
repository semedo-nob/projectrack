// lib/ui/projects/projects_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/service/export_service.dart';
import 'package:projectrack1/ui/projects/widgets/projects_card.dart';
import 'package:provider/provider.dart';

import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../widgets/enterprise_ui.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  // Search and Filter Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Selection State
  final Set<String> _selectedProjectIds = {};
  bool _isSelectionMode = false;
  bool _isExporting = false;

  // Filter State
  String _selectedFilter = 'All';
  String _searchQuery = '';
  RangeValues _budgetRange = const RangeValues(0, 50000);
  double _maxBudget = 50000;

  // Sort State
  String _sortBy = 'name';
  bool _sortAscending = true;

  // View State
  bool _isGridView = true; // Toggle between grid and list view

  // Projects Data
  List<Project> _allProjects = [];
  List<Project> _filteredProjects = [];
  bool _isLoadingProjects = true;
  StreamSubscription<List<Project>>? _projectsSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
  }

  Future<void> _loadProjects() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final list = await db.getAllProjects();
    if (!mounted) return;
    setState(() {
      _allProjects = list;
      _maxBudget = list.isEmpty
          ? 0
          : list.map((p) => p.budget).reduce((a, b) => a > b ? a : b);
      _budgetRange = RangeValues(0, _maxBudget > 0 ? _maxBudget : 1);
      _applyFilters();
      _isLoadingProjects = false;
    });
    _projectsSubscription?.cancel();
    _projectsSubscription = db.projectsStream.listen((list) {
      if (!mounted) return;
      setState(() {
        _allProjects = list;
        _maxBudget = list.isEmpty
            ? 0
            : list.map((p) => p.budget).reduce((a, b) => a > b ? a : b);
        _budgetRange = RangeValues(0, _maxBudget > 0 ? _maxBudget : 1);
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _projectsSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredProjects = _allProjects.where((project) {
      // Search filter
      bool matchesSearch =
          _searchQuery.isEmpty ||
          project.name.toLowerCase().contains(_searchQuery) ||
          project.description.toLowerCase().contains(_searchQuery) ||
          project.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)) ||
          project.category.toLowerCase().contains(_searchQuery);

      // Budget filter
      bool matchesBudget =
          project.budget >= _budgetRange.start &&
          project.budget <= _budgetRange.end;

      // Status filter
      bool matchesStatus =
          _selectedFilter == 'All' || project.status == _selectedFilter;

      return matchesSearch && matchesBudget && matchesStatus;
    }).toList();

    _sortProjects();
  }

  void _sortProjects() {
    _filteredProjects.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'budget':
          comparison = a.budget.compareTo(b.budget);
          break;
        case 'progress':
          comparison = a.progress.compareTo(b.progress);
          break;
        case 'date':
          comparison = a.startDate.compareTo(b.startDate);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _toggleSelection(String projectId) {
    setState(() {
      if (_selectedProjectIds.contains(projectId)) {
        _selectedProjectIds.remove(projectId);
      } else {
        _selectedProjectIds.add(projectId);
      }
      _isSelectionMode = _selectedProjectIds.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedProjectIds.length == _filteredProjects.length) {
        _selectedProjectIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedProjectIds.addAll(_filteredProjects.map((p) => p.id));
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProjectIds.clear();
      _isSelectionMode = false;
    });
  }

  /// Resolves which project IDs to export, then fetches current project list from DB
  /// so that export uses realtime data (spent, budget, expenses).
  Future<List<Project>?> _resolveProjectsToExport() async {
    final Set<String> ids = _selectedProjectIds.isEmpty
        ? _filteredProjects.map((p) => p.id).toSet()
        : _selectedProjectIds;
    if (ids.isEmpty) return null;
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final allProjects = await db.getAllProjects();
    final list = allProjects.where((p) => ids.contains(p.id)).toList();
    return list.isEmpty ? null : list;
  }

  Future<void> _exportToExcel() async {
    try {
      final projectsToExport = await _resolveProjectsToExport();
      if (projectsToExport == null || projectsToExport.isEmpty) {
        _showSnackBar('No projects to export', AppColors.warning);
        return;
      }

      setState(() => _isExporting = true);

      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final savedPath = await ExportService.instance.exportProjectsToExcel(
        projects: projectsToExport,
        expensesLoader: db.getExpensesByProject,
      );
      if (!mounted) return;
      await _showExportResultDialog(
        formatLabel: 'Excel',
        savedPath: savedPath,
        count: projectsToExport.length,
      );
      _clearSelection();
    } catch (e) {
      _showSnackBar('Error exporting: $e', AppColors.error);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToCsv() async {
    try {
      final projectsToExport = await _resolveProjectsToExport();
      if (projectsToExport == null || projectsToExport.isEmpty) {
        _showSnackBar('No projects to export', AppColors.warning);
        return;
      }

      setState(() => _isExporting = true);

      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final savedPath = await ExportService.instance.exportProjectsToCsv(
        projects: projectsToExport,
        expensesLoader: db.getExpensesByProject,
      );
      if (!mounted) return;
      await _showExportResultDialog(
        formatLabel: 'CSV',
        savedPath: savedPath,
        count: projectsToExport.length,
      );
      _clearSelection();
    } catch (e) {
      _showSnackBar('Error exporting CSV: $e', AppColors.error);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showExportResultDialog({
    required String formatLabel,
    required String savedPath,
    required int count,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$formatLabel Export Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exported $count project(s) to:'),
              const SizedBox(height: 8),
              SelectableText(savedPath),
              const SizedBox(height: 12),
              const Text(
                'Choose Open File to let Android or iOS ask which viewer to use.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: savedPath));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                _showSnackBar('File path copied', AppColors.success);
              },
              child: const Text('Copy Path'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await OpenFilex.open(savedPath);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (result.type != ResultType.done) {
                  _showSnackBar(
                    result.message.isEmpty
                        ? 'No viewer app was available to open this file.'
                        : result.message,
                    AppColors.warning,
                  );
                }
              },
              child: const Text('Open File'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedFilter: _selectedFilter,
        budgetRange: _budgetRange,
        maxBudget: _maxBudget,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        onApply: (filter, range, sortBy, ascending) {
          setState(() {
            _selectedFilter = filter;
            _budgetRange = range;
            _sortBy = sortBy;
            _sortAscending = ascending;
            _applyFilters();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      body: CustomScrollView(
        slivers: [
          // App Bar
          _buildAppBar(isDark),

          // Search Bar
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EnterpriseUi.padH, 8, EnterpriseUi.padH, 12),
            sliver: SliverToBoxAdapter(child: _buildSearchBar(isDark)),
          ),

          // Filter Chips
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: EnterpriseUi.padH),
            sliver: SliverToBoxAdapter(child: _buildFilterChips(isDark)),
          ),

          // Results Count and View Toggle
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EnterpriseUi.padH, 12, EnterpriseUi.padH, 8),
            sliver: SliverToBoxAdapter(child: _buildResultsCount(isDark)),
          ),

          // Projects Grid/List
          _buildProjectsView(isDark),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 0,
      title: _isSelectionMode
          ? Text(
              '${_selectedProjectIds.length} selected',
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w600,
              ),
            )
          : const Text(
              'Projects',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
      leading: _isSelectionMode
          ? IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              onPressed: _clearSelection,
            )
          : IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              onPressed: () => context.go(AppRoutes.home),
            ),
      actions: [
        if (_isSelectionMode)
          IconButton(
            icon: Icon(
              Icons.select_all_rounded,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            onPressed: _selectAll,
          ),
        if (_isSelectionMode && _selectedProjectIds.isNotEmpty)
          Stack(
            alignment: Alignment.center,
            children: [
              if (_isExporting)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                enabled: !_isExporting,
                icon: Icon(
                  Icons.download_rounded,
                  color: _isExporting ? Colors.transparent : AppColors.primary,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'excel',
                    child: ListTile(
                      leading: Icon(Icons.table_chart_rounded),
                      title: Text('Export as Excel (.xlsx)'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv',
                    child: ListTile(
                      leading: Icon(Icons.description_rounded),
                      title: Text('Export as CSV (.csv)'),
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'excel') _exportToExcel();
                  if (value == 'csv') _exportToCsv();
                },
              ),
            ],
          ),
        if (!_isSelectionMode) ...[
          // View Toggle Button
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            tooltip: _isGridView
                ? 'Switch to List View'
                : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: Icon(
              Icons.checklist_rounded,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            tooltip: 'Select projects for export',
            onPressed: () => setState(() => _isSelectionMode = true),
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search projects…',
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            isSelected: _selectedFilter == 'All',
            count: _allProjects.length,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Active',
            isSelected: _selectedFilter == 'Active',
            count: _allProjects.where((p) => p.status == 'Active').length,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Planning',
            isSelected: _selectedFilter == 'Planning',
            count: _allProjects.where((p) => p.status == 'Planning').length,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Done',
            isSelected: _selectedFilter == 'Done',
            count: _allProjects.where((p) => p.status == 'Done').length,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required int count,
    required bool isDark,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.black.withOpacity(0.1)
                  : (isDark
                        ? AppColors.darkTextTertiary
                        : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.black
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _applyFilters();
        });
      },
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.black,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.black
            : (isDark ? AppColors.darkText : AppColors.lightText),
      ),
    );
  }

  Widget _buildResultsCount(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_filteredProjects.length} project${_filteredProjects.length != 1 ? 's' : ''} found',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        if (_filteredProjects.isNotEmpty)
          Row(
            children: [
              PopupMenuButton<String>(
                enabled: !_isExporting,
                icon: _isExporting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                tooltip: 'Export',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'excel',
                    child: Text('Export as Excel (.xlsx)'),
                  ),
                  const PopupMenuItem(
                    value: 'csv',
                    child: Text('Export as CSV (.csv)'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'excel') _exportToExcel();
                  if (value == 'csv') _exportToCsv();
                },
              ),
              Text(
                _selectedProjectIds.isEmpty
                    ? 'Export all'
                    : 'Export (${_selectedProjectIds.length})',
                style: TextStyle(color: AppColors.primary, fontSize: 14),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildProjectsView(bool isDark) {
    if (_isLoadingProjects) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading projects...',
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

    if (_filteredProjects.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
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
                  _allProjects.isEmpty
                      ? 'No projects yet'
                      : 'No projects found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _allProjects.isEmpty
                      ? 'Create a project to get started'
                      : 'Try adjusting your filters',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isGridView) {
      // Grid View
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            // Slightly taller cells so project cards (image + meta + progress) fit on small widths.
            childAspectRatio: 0.72,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final project = _filteredProjects[index];
            final isSelected = _selectedProjectIds.contains(project.id);

            return ProjectCard(
              project: project,
              isSelected: isSelected,
              isDark: isDark,
              isListView: false,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(project.id);
                } else {
                  context.push(
                    AppRoutes.projectOverview.replaceFirst(':id', project.id),
                    extra: project.name,
                  );
                }
              },
              onLongPress: () => _toggleSelection(project.id),
            );
          }, childCount: _filteredProjects.length),
        ),
      );
    } else {
      // List View
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final project = _filteredProjects[index];
            final isSelected = _selectedProjectIds.contains(project.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProjectCard(
                project: project,
                isSelected: isSelected,
                isDark: isDark,
                isListView: true,
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(project.id);
                  } else {
                    context.push(
                      AppRoutes.projectOverview.replaceFirst(':id', project.id),
                      extra: project.name,
                    );
                  }
                },
                onLongPress: () => _toggleSelection(project.id),
              ),
            );
          }, childCount: _filteredProjects.length),
        ),
      );
    }
  }
}

// Filter Bottom Sheet (Separate Widget)
class _FilterBottomSheet extends StatefulWidget {
  final String selectedFilter;
  final RangeValues budgetRange;
  final double maxBudget;
  final String sortBy;
  final bool sortAscending;
  final Function(String, RangeValues, String, bool) onApply;

  const _FilterBottomSheet({
    Key? key,
    required this.selectedFilter,
    required this.budgetRange,
    required this.maxBudget,
    required this.sortBy,
    required this.sortAscending,
    required this.onApply,
  }) : super(key: key);

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _selectedFilter;
  late RangeValues _budgetRange;
  late String _sortBy;
  late bool _sortAscending;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedFilter;
    _budgetRange = widget.budgetRange;
    _sortBy = widget.sortBy;
    _sortAscending = widget.sortAscending;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Filter & Sort',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  _buildStatusSection(isDark),

                  const SizedBox(height: 24),

                  // Budget Range
                  _buildBudgetSection(isDark),

                  const SizedBox(height: 24),

                  // Sort By
                  _buildSortSection(isDark),
                ],
              ),
            ),
          ),

          // Apply Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    _selectedFilter,
                    _budgetRange,
                    _sortBy,
                    _sortAscending,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['All', 'Active', 'Planning', 'On Hold', 'Done'].map((
            status,
          ) {
            return FilterChip(
              label: Text(status),
              selected: _selectedFilter == status,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = status;
                });
              },
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.black,
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.lightSurface,
              labelStyle: TextStyle(
                color: _selectedFilter == status
                    ? Colors.black
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBudgetSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget Range',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 16),
        RangeSlider(
          values: _budgetRange,
          min: 0,
          max: widget.maxBudget,
          divisions: 10,
          activeColor: AppColors.primary,
          inactiveColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          labels: RangeLabels(
            '\$${_budgetRange.start.round()}',
            '\$${_budgetRange.end.round()}',
          ),
          onChanged: (values) {
            setState(() {
              _budgetRange = values;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\$${_budgetRange.start.round()}',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            Text(
              '\$${_budgetRange.end.round()}',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort By',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'name', label: Text('Name')),
            ButtonSegment(value: 'budget', label: Text('Budget')),
            ButtonSegment(value: 'progress', label: Text('Progress')),
            ButtonSegment(value: 'date', label: Text('Date')),
          ],
          selected: {_sortBy},
          onSelectionChanged: (Set<String> selection) {
            setState(() {
              _sortBy = selection.first;
            });
          },
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return AppColors.primary;
              }
              return isDark ? AppColors.darkCard : AppColors.lightSurface;
            }),
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.black;
              }
              return isDark ? AppColors.darkText : AppColors.lightText;
            }),
          ),
        ),

        const SizedBox(height: 16),

        // Sort Order
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Ascending'),
                selected: _sortAscending,
                onSelected: (selected) {
                  setState(() {
                    _sortAscending = true;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: isDark
                    ? AppColors.darkCard
                    : AppColors.lightSurface,
                labelStyle: TextStyle(
                  color: _sortAscending
                      ? Colors.black
                      : (isDark ? AppColors.darkText : AppColors.lightText),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('Descending'),
                selected: !_sortAscending,
                onSelected: (selected) {
                  setState(() {
                    _sortAscending = false;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: isDark
                    ? AppColors.darkCard
                    : AppColors.lightSurface,
                labelStyle: TextStyle(
                  color: !_sortAscending
                      ? Colors.black
                      : (isDark ? AppColors.darkText : AppColors.lightText),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
