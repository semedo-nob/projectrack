// lib/ui/projects/projects_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/ui/projects/widgets/projects_card.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

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

  // Filter State
  String _selectedFilter = 'All';
  String _searchQuery = '';
  RangeValues _budgetRange = const RangeValues(0, 50000);
  double _maxBudget = 50000;

  // Sort State
  String _sortBy = 'name';
  bool _sortAscending = true;

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
      _maxBudget = list.isEmpty ? 0 : list.map((p) => p.budget).reduce((a, b) => a > b ? a : b);
      _budgetRange = RangeValues(0, _maxBudget > 0 ? _maxBudget : 1);
      _applyFilters();
      _isLoadingProjects = false;
    });
    _projectsSubscription?.cancel();
    _projectsSubscription = db.projectsStream.listen((list) {
      if (!mounted) return;
      setState(() {
        _allProjects = list;
        _maxBudget = list.isEmpty ? 0 : list.map((p) => p.budget).reduce((a, b) => a > b ? a : b);
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
      bool matchesSearch = _searchQuery.isEmpty ||
          project.name.toLowerCase().contains(_searchQuery) ||
          project.description.toLowerCase().contains(_searchQuery) ||
          project.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)) ||
          project.category.toLowerCase().contains(_searchQuery);

      // Budget filter
      bool matchesBudget = project.budget >= _budgetRange.start &&
          project.budget <= _budgetRange.end;

      // Status filter
      bool matchesStatus = _selectedFilter == 'All' ||
          project.status == _selectedFilter;

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

  Future<void> _exportToExcel() async {
    try {
      List<Project> projectsToExport = _selectedProjectIds.isEmpty
          ? _filteredProjects
          : _allProjects.where((p) => _selectedProjectIds.contains(p.id)).toList();

      if (projectsToExport.isEmpty) {
        _showSnackBar('No projects to export', AppColors.warning);
        return;
      }

      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final dateFmt = DateFormat('yyyy-MM-dd');

      var excel = Excel.createExcel();
      // Sheet 1: Project Logs (project name, logs by date, entry name as user gave)
      Sheet logSheet = excel['Project Logs'];
      logSheet.appendRow([
        TextCellValue('Project Name'),
        TextCellValue('Date'),
        TextCellValue('Entry Name'),
        TextCellValue('Merchant'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
      ]);
      _styleHeaderRow(logSheet, 0, 6);

      int logRow = 1;
      for (var project in projectsToExport) {
        List<Expense> expenses = await db.getExpensesByProject(project.id);
        expenses.sort((a, b) => a.date.compareTo(b.date));
        for (var e in expenses) {
          final entryName = (e.notes != null && e.notes!.trim().isNotEmpty)
              ? e.notes!
              : e.merchant;
          logSheet.appendRow([
            TextCellValue(project.name),
            TextCellValue(dateFmt.format(e.date)),
            TextCellValue(entryName),
            TextCellValue(e.merchant),
            TextCellValue(e.category.displayName),
            DoubleCellValue(e.amount),
          ]);
          logRow++;
        }
      }

      // Sheet 2: Projects summary
      Sheet summarySheet = excel['Projects'];
      summarySheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Description'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Budget'),
        TextCellValue('Spent'),
        TextCellValue('Status'),
        TextCellValue('Category'),
        TextCellValue('Progress %'),
      ]);
      _styleHeaderRow(summarySheet, 0, 9);
      for (var project in projectsToExport) {
        summarySheet.appendRow([
          TextCellValue(project.name),
          TextCellValue(project.description),
          TextCellValue(dateFmt.format(project.startDate)),
          TextCellValue(project.endDate != null ? dateFmt.format(project.endDate!) : 'N/A'),
          DoubleCellValue(project.budget),
          DoubleCellValue(project.spent),
          TextCellValue(project.status),
          TextCellValue(project.category),
          DoubleCellValue((project.progress * 100).clamp(0.0, 100.0)),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName = 'projects_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        _showSnackBar(
          'Exported ${projectsToExport.length} project(s) with logs',
          AppColors.success,
        );
        _clearSelection();
      }
    } catch (e) {
      _showSnackBar('Error exporting: $e', AppColors.error);
    }
  }

  void _styleHeaderRow(Sheet sheet, int rowIndex, int colCount) {
    for (var col = 0; col < colCount; col++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: col));
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#5A4FCF'),
        bold: true,
        textWrapping: TextWrapping.WrapText,
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // App Bar
          _buildAppBar(isDark),

          // Search Bar
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(child: _buildSearchBar(isDark)),
          ),

          // Filter Chips
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildFilterChips(isDark)),
          ),

          // Results Count
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(child: _buildResultsCount(isDark)),
          ),

          // Projects Grid
          _buildProjectsGrid(isDark),
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
          IconButton(
            icon: Icon(
              Icons.download_rounded,
              color: AppColors.primary,
            ),
            onPressed: _exportToExcel,
          ),
        if (!_isSelectionMode) ...[
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
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            onPressed: () {
              FocusScope.of(context).requestFocus(_searchFocusNode);
            },
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
          hintText: 'Search by name, tags, category...',
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.clear_rounded,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  : (isDark ? AppColors.darkTextTertiary : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87),
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
          '${_filteredProjects.length} projects found',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        if (_filteredProjects.isNotEmpty)
          TextButton.icon(
            onPressed: _exportToExcel,
            icon: Icon(
              Icons.download_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              _selectedProjectIds.isEmpty
                  ? 'Export all'
                  : 'Export (${_selectedProjectIds.length} selected)',
              style: TextStyle(color: AppColors.primary),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
      ],
    );
  }

  Widget _buildProjectsGrid(bool isDark) {
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
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              Icon(
                Icons.folder_off_rounded,
                size: 64,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                _allProjects.isEmpty ? 'No projects yet' : 'No projects found',
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
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final project = _filteredProjects[index];
            final isSelected = _selectedProjectIds.contains(project.id);

            return ProjectCard(
              project: project,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(project.id);
                } else {
                  context.push('/project/${project.id}', extra: project.name);
                }
              },
              onLongPress: () => _toggleSelection(project.id),
            );
          },
          childCount: _filteredProjects.length,
        ),
      ),
    );
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
                  widget.onApply(_selectedFilter, _budgetRange, _sortBy, _sortAscending);
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
          children: ['All', 'Active', 'Planning', 'On Hold', 'Done'].map((status) {
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
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
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
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            Text(
              '\$${_budgetRange.end.round()}',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
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
                backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
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