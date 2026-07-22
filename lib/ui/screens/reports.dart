// lib/ui/reports/reports_analytics_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/providers/auth_provider.dart';
import 'package:projectrack1/service/export_service.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../service/expense_duplicate_service.dart';
import '../../constants/models/task_model.dart';
import '../widgets/enterprise_ui.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  final String? projectId;
  final String? projectName;

  const ReportsAnalyticsScreen({super.key, this.projectId, this.projectName});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  /// Preset + Custom (Custom uses [_customRangeStart]/[_customRangeEnd]).
  String _periodFilter = 'This Month';
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;
  bool _loading = true;
  String? _error;

  /// Sum of expenses in the selected date range (matches user activity in the app).
  double _periodSpent = 0;

  /// Sum of `project.spent` for projects in scope (aligned with Drift rollups).
  double _allTimeSpent = 0;

  double _totalBudget = 0;
  double _remaining = 0;
  int _expenseCountInPeriod = 0;

  // Task data (scoped to selected projects)
  int _taskDone = 0;
  int _taskActive = 0;
  int _taskTodo = 0;
  int _taskTotal = 0;
  int _taskOverdue = 0;
  int _missingReceiptCount = 0;
  int _pendingReviewCount = 0;
  int _repeatPurchaseGroups = 0;
  int _repeatPurchaseCount = 0;

  // Category data (period-filtered)
  List<Map<String, dynamic>> _categoryBreakdown = [];

  /// Spending per project (period) — pie chart + colors
  List<Map<String, dynamic>> _projectBreakdown = [];

  /// Material line chart: top materials, one series per material (bucketed over time).
  List<String> _materialTrendNames = [];
  List<List<double>> _materialTrendSeries = [];
  List<Color> _materialLineColors = [];
  List<String> _materialTrendXLabels = [];

  /// Same time buckets as material chart: all spend vs materials-only (for comparison line chart).
  List<double> _allSpendByBucket = [];
  List<double> _materialOnlyByBucket = [];

  /// Daily bars: per-day stacked amounts per project (same project order each day).
  List<String> _dailyProjectIds = [];
  List<String> _dailyProjectNames = [];
  List<Color> _dailyProjectColors = [];
  List<List<double>> _dailyStacksByDay = [];
  List<String> _dailyBarLabels = [];

  // Animation controller for refresh indicator
  late AnimationController _refreshController;

  /// Drift project watch — expenses update `project.spent`, so reports stay in sync with app data.
  StreamSubscription<List<Project>>? _projectsSubscription;
  Timer? _reloadDebounce;

  static const List<Color> _categoryColors = [
    AppColors.primary,
    AppColors.success,
    AppColors.secondary,
    AppColors.warning,
    AppColors.info,
    AppColors.error,
  ];

  /// Distinct colors for projects (cycles if many projects).
  static const List<Color> _projectPalette = [
    AppColors.primary,
    AppColors.success,
    AppColors.secondary,
    AppColors.warning,
    AppColors.info,
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFF795548),
    Color(0xFFE91E63),
    Color(0xFF3F51B5),
  ];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      _projectsSubscription = db.projectsStream.listen(
        (_) => _scheduleReloadFromDb(),
      );
    });
  }

  void _scheduleReloadFromDb() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadReportData();
    });
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _projectsSubscription?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  ({DateTime start, DateTime end}) _periodBounds() {
    final now = DateTime.now();
    final today = _dateOnly(now);
    switch (_periodFilter) {
      case 'Today':
        return (start: today, end: today);
      case 'Yesterday':
        final y = today.subtract(const Duration(days: 1));
        return (start: y, end: y);
      case 'This Week':
        final weekday = today.weekday;
        final monday = today.subtract(Duration(days: weekday - 1));
        return (start: monday, end: today);
      case 'Last 7 Days':
        return (start: today.subtract(const Duration(days: 6)), end: today);
      case 'Last 30 Days':
        return (start: today.subtract(const Duration(days: 29)), end: today);
      case 'This Month':
        return (start: DateTime(now.year, now.month, 1), end: today);
      case 'This Quarter':
        final q = (now.month - 1) ~/ 3;
        final startMonth = q * 3 + 1;
        return (start: DateTime(now.year, startMonth, 1), end: today);
      case 'This Year':
        return (start: DateTime(now.year, 1, 1), end: today);
      case 'Custom':
        if (_customRangeStart != null && _customRangeEnd != null) {
          var s = _dateOnly(_customRangeStart!);
          var e = _dateOnly(_customRangeEnd!);
          if (e.isBefore(s)) {
            final t = s;
            s = e;
            e = t;
          }
          return (start: s, end: e);
        }
        return (start: today, end: today);
      default:
        return (start: DateTime(now.year, now.month, 1), end: today);
    }
  }

  static int _lineChartBucketCount(int totalDays) {
    if (totalDays <= 0) return 1;
    if (totalDays <= 31) return totalDays;
    if (totalDays <= 90) return 13;
    return 12;
  }

  static int _bucketIndexForDayIndex(
    int dayIndex,
    int totalDays,
    int bucketCount,
  ) {
    if (totalDays <= 0 || bucketCount <= 0) return 0;
    if (bucketCount >= totalDays) return dayIndex.clamp(0, totalDays - 1);
    final seg = totalDays / bucketCount;
    return (dayIndex / seg).floor().clamp(0, bucketCount - 1);
  }

  static Color _colorForProjectId(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _projectPalette[h.abs() % _projectPalette.length];
  }

  double _safeChartMax(double value) {
    if (!value.isFinite || value <= 0) return 1;
    return value * 1.15;
  }

  bool _shouldShowXAxisLabel(int index, int total) {
    if (total <= 6) return true;
    if (index == 0 || index == total - 1) return true;
    final step = math.max(1, (total / 4).ceil());
    return index % step == 0;
  }

  /// fl_chart LineChart often draws nothing with a single point — duplicate so lines render.
  List<double> _ensureMinTwoChartPoints(List<double> values) {
    if (values.isEmpty) return [0, 0];
    if (values.length == 1) return [values[0], values[0]];
    return values;
  }

  List<String> _alignXLabels(List<String> labels, int pointCount) {
    if (labels.length >= pointCount) {
      return labels.take(pointCount).toList(growable: false);
    }
    if (pointCount == 2 && labels.length == 1) {
      return [labels[0], labels[0]];
    }
    return List.generate(
      pointCount,
      (i) => i < labels.length ? labels[i] : '',
    );
  }

  double _lineChartMaxX(int pointCount) {
    if (pointCount <= 1) return 1;
    return (pointCount - 1).toDouble();
  }

  /// fl_chart axis callbacks must never throw (e.g. NaN → toInt()).
  String _formatAxisYLabel(double v) {
    if (!v.isFinite) return '';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.round().toString();
  }

  int? _axisXIndex(double v, int labelCount) {
    if (!v.isFinite || labelCount <= 0) return null;
    return v.round().clamp(0, labelCount - 1);
  }

  String _materialLabelFromExpense(Expense e) {
    if (e.category != ExpenseCategory.materials) return '';
    final n = e.notes?.trim();
    if (n != null && n.isNotEmpty) {
      final ix = n.lastIndexOf(' x ');
      if (ix > 0) return n.substring(0, ix).trim();
      return n;
    }
    return e.merchant.trim().isNotEmpty ? e.merchant.trim() : 'Materials';
  }

  Future<void> _pickCustomDateRange(bool isDark) async {
    final now = DateTime.now();
    final initialStart =
        _customRangeStart ?? now.subtract(const Duration(days: 7));
    final initialEnd = _customRangeEnd ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _periodFilter = 'Custom';
      _customRangeStart = picked.start;
      _customRangeEnd = picked.end;
    });
    _loadReportData();
  }

  /// Short title for the selected preset (sentence case).
  String _friendlyPeriodHeadline() {
    switch (_periodFilter) {
      case 'Today':
        return 'Today';
      case 'Yesterday':
        return 'Yesterday';
      case 'This Week':
        return 'This week';
      case 'Last 7 Days':
        return 'Last 7 days';
      case 'This Month':
        return 'This month';
      case 'Last 30 Days':
        return 'Last 30 days';
      case 'This Quarter':
        return 'This quarter';
      case 'This Year':
        return 'This year';
      case 'Custom':
        return 'Custom range';
      default:
        return _periodFilter;
    }
  }

  /// Concrete calendar range from [_periodBounds] for subtitles and chips.
  String _friendlyDateRangeLine() {
    final b = _periodBounds();
    final start = b.start;
    final end = b.end;
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('EEEE, d MMM yyyy').format(start);
    }
    final sameYear = start.year == end.year;
    final sameMonth = sameYear && start.month == end.month;
    if (sameMonth) {
      return '${DateFormat('d').format(start)}–${DateFormat('d MMM yyyy').format(end)}';
    }
    if (sameYear) {
      return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
    }
    return '${DateFormat('d MMM yyyy').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
  }

  /// PDF/CSV and exports: human-readable period description.
  String _periodLabelForExport() {
    return '${_friendlyPeriodHeadline()} · ${_friendlyDateRangeLine()}';
  }

  void _selectPresetAndReload(String filter) {
    setState(() => _periodFilter = filter);
    _loadReportData();
  }

  void _showPeriodPickerSheet(bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget section(String title, List<Widget> tiles) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ),
              ...tiles,
            ],
          );
        }

        Widget tile(String label, String filterKey, {String? hint}) {
          final selected = _periodFilter == filterKey;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            subtitle: hint == null
                ? null
                : Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
            trailing: selected
                ? Icon(Icons.check_rounded, color: AppColors.primary, size: 22)
                : null,
            onTap: () {
              Navigator.of(sheetContext).pop();
              _selectPresetAndReload(filterKey);
            },
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Text(
                          'Reporting period',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Choose how far back to include expenses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                section('Today & yesterday', [
                  tile('Today', 'Today'),
                  tile('Yesterday', 'Yesterday'),
                ]),
                section('This period', [
                  tile(
                    'This week',
                    'This Week',
                    hint: 'From Monday through today',
                  ),
                  tile(
                    'This month',
                    'This Month',
                    hint: 'From the 1st through today',
                  ),
                  tile('This quarter', 'This Quarter'),
                  tile('This year', 'This Year'),
                ]),
                section('Rolling window', [
                  tile(
                    'Last 7 days',
                    'Last 7 Days',
                    hint: 'Including today',
                  ),
                  tile(
                    'Last 30 days',
                    'Last 30 Days',
                    hint: 'Including today',
                  ),
                ]),
                const Divider(height: 1),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Icon(
                    Icons.date_range_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Choose dates…'),
                  subtitle: Text(
                    'Pick any start and end date',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickCustomDateRange(isDark);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EnterpriseUi.padH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnterpriseUi.sectionLabel('Time period', isDark),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showPeriodPickerSheet(isDark),
              borderRadius: BorderRadius.circular(EnterpriseUi.radiusMd),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: EnterpriseUi.groupedListDecoration(isDark),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _friendlyPeriodHeadline(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _friendlyDateRangeLine(),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Quick presets',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickPeriodChip(isDark, 'Today', 'Today'),
              _quickPeriodChip(isDark, 'This week', 'This Week'),
              _quickPeriodChip(isDark, 'This month', 'This Month'),
              _quickPeriodChip(isDark, 'Last 30 days', 'Last 30 Days'),
              ActionChip(
                avatar: Icon(
                  Icons.edit_calendar_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: const Text('Pick dates'),
                onPressed: () => _pickCustomDateRange(isDark),
                backgroundColor:
                    isDark ? AppColors.darkCard : AppColors.lightSurface,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                labelStyle: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickPeriodChip(bool isDark, String label, String filterKey) {
    final selected = _periodFilter == filterKey;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => _selectPresetAndReload(filterKey),
      selectedColor: AppColors.primary.withOpacity(0.35),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
            ? Colors.black87
            : (isDark ? AppColors.darkText : AppColors.lightText),
      ),
    );
  }

  static bool _expenseInPeriod(
    DateTime expenseDate,
    DateTime start,
    DateTime end,
  ) {
    final d = _dateOnly(expenseDate);
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  static void _classifyTask(
    String status,
    void Function() onDone,
    void Function() onTodo,
    void Function() onActive,
  ) {
    final s = status.trim().toLowerCase();
    if (s == 'done') {
      onDone();
    } else if (s.contains('todo') ||
        s.contains('not started') ||
        s == 'pending' ||
        s.isEmpty) {
      onTodo();
    } else {
      onActive();
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.currentUser?.id;
      if (currentUserId != null) {
        db.setActiveUserId(currentUserId);
      }
      final projects = await db.getAllProjects();
      final projectIds =
          widget.projectId != null && widget.projectId!.isNotEmpty
          ? [widget.projectId!]
          : projects.map((p) => p.id).toList();

      final inScope = projects.where((p) => projectIds.contains(p.id)).toList();
      _totalBudget = inScope.fold(0.0, (a, Project p) => a + p.budget);
      _allTimeSpent = inScope.fold(0.0, (a, Project p) => a + p.spent);
      _remaining = _totalBudget - _allTimeSpent;

      final bounds = _periodBounds();
      final rangeStart = bounds.start;
      final rangeEnd = bounds.end;

      final categoryTotals = <String, double>{};
      final projectTotals = <String, double>{};
      final projectIdToName = <String, String>{
        for (final p in inScope) p.id: p.name,
      };

      var taskDone = 0;
      var taskActive = 0;
      var taskTodo = 0;
      var taskTotal = 0;
      var taskOverdue = 0;
      var missingReceipts = 0;
      var pendingReview = 0;
      var periodSpent = 0.0;
      var expenseCount = 0;
      final periodExpensesForDupes = <Expense>[];

      final totalDays = rangeEnd.difference(rangeStart).inDays + 1;
      final bucketCount = _lineChartBucketCount(totalDays);
      final rangeStart0 = _dateOnly(rangeStart);
      final rangeEnd0 = _dateOnly(rangeEnd);

      final materialBuckets = <String, List<double>>{};
      const maxMaterialLines = 6;
      final allSpendByBucket = List<double>.filled(bucketCount, 0);
      final materialOnlyByBucket = List<double>.filled(bucketCount, 0);

      final sortedProjectIds = List<String>.from(projectIds)
        ..sort(
          (a, b) => (projectIdToName[a] ?? a).toLowerCase().compareTo(
            (projectIdToName[b] ?? b).toLowerCase(),
          ),
        );

      // Up to 14 days ending at period end — stacked by project (not cumulative across days).
      final span = math.min(14, totalDays);
      var barStart = rangeEnd0.subtract(Duration(days: span - 1));
      if (barStart.isBefore(rangeStart0)) barStart = rangeStart0;
      final barDays = <DateTime>[];
      for (
        var d = barStart;
        !d.isAfter(rangeEnd0);
        d = d.add(const Duration(days: 1))
      ) {
        barDays.add(_dateOnly(d));
      }
      final dailyStacksByDay = List.generate(
        barDays.length,
        (_) => List<double>.filled(sortedProjectIds.length, 0),
      );
      final dailyBarLabels = barDays
          .map((d) => DateFormat('E d').format(d))
          .toList();

      for (final id in projectIds) {
        final expenses = await db.getExpensesByProject(id);
        for (final e in expenses) {
          if (!_expenseInPeriod(e.date, rangeStart, rangeEnd)) continue;

          periodSpent += e.amount;
          expenseCount++;
          periodExpensesForDupes.add(e);
          if (!e.hasReceipt) missingReceipts++;
          if (e.status == ExpenseStatus.pendingReview) pendingReview++;

          final cat = e.category.displayName;
          categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
          projectTotals[e.projectId] =
              (projectTotals[e.projectId] ?? 0) + e.amount;

          final day0 = _dateOnly(e.date);
          final dayIndex = day0.difference(rangeStart0).inDays;
          if (dayIndex >= 0 && dayIndex < totalDays) {
            final bi = _bucketIndexForDayIndex(
              dayIndex,
              totalDays,
              bucketCount,
            );
            allSpendByBucket[bi] += e.amount;
            if (e.category == ExpenseCategory.materials) {
              materialOnlyByBucket[bi] += e.amount;
            }
            final mat = _materialLabelFromExpense(e);
            if (mat.isNotEmpty) {
              materialBuckets.putIfAbsent(
                mat,
                () => List<double>.filled(bucketCount, 0),
              );
              materialBuckets[mat]![bi] += e.amount;
            }
          }

          final j = barDays.indexWhere((x) => x == day0);
          if (j >= 0) {
            final pi = sortedProjectIds.indexOf(e.projectId);
            if (pi >= 0) dailyStacksByDay[j][pi] += e.amount;
          }
        }

        final tasks = await db.getTasksByProject(id);
        for (final t in tasks) {
          taskTotal++;
          final status = TaskStatus.fromString(t.status);
          if (status == TaskStatus.done) {
            taskDone++;
          } else if (status == TaskStatus.pending) {
            taskTodo++;
          } else {
            taskActive++;
          }
          final due = t.dueDate;
          if (due != null && status != TaskStatus.done) {
            final dueDay = DateTime(due.year, due.month, due.day);
            final today = DateTime.now();
            final todayDay = DateTime(today.year, today.month, today.day);
            if (dueDay.isBefore(todayDay)) taskOverdue++;
          }
        }
      }

      final duplicateGroups =
          const ExpenseDuplicateService().findRepeatGroups(periodExpensesForDupes);
      final repeatPurchaseCount = duplicateGroups.fold<int>(
        0,
        (sum, group) => sum + group.length,
      );

      _periodSpent = periodSpent;
      _expenseCountInPeriod = expenseCount;
      _taskTotal = taskTotal;
      _taskDone = taskDone;
      _taskActive = taskActive;
      _taskTodo = taskTodo;
      _taskOverdue = taskOverdue;
      _missingReceiptCount = missingReceipts;
      _pendingReviewCount = pendingReview;
      _repeatPurchaseGroups = duplicateGroups.length;
      _repeatPurchaseCount = repeatPurchaseCount;

      // Top materials by total spend in period
      final materialTotals = <String, double>{};
      for (final e in materialBuckets.entries) {
        materialTotals[e.key] = e.value.fold(0.0, (a, b) => a + b);
      }
      final topMaterials = materialTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final picked = topMaterials
          .take(maxMaterialLines)
          .map((e) => e.key)
          .toList();
      _materialTrendNames = picked;
      _materialTrendSeries = picked
          .map(
            (name) => List<double>.from(
              materialBuckets[name] ?? List<double>.filled(bucketCount, 0),
            ),
          )
          .toList();
      _materialLineColors = List.generate(
        picked.length,
        (i) => _categoryColors[i % _categoryColors.length],
      );

      _materialTrendXLabels = List<String>.generate(bucketCount, (i) {
        if (bucketCount >= totalDays) {
          final day = rangeStart0.add(Duration(days: i));
          return DateFormat('MMM d').format(day);
        }
        final startIdx = (i * totalDays / bucketCount).floor();
        final day = rangeStart0.add(
          Duration(days: startIdx.clamp(0, totalDays - 1)),
        );
        return DateFormat('MMM d').format(day);
      });

      _allSpendByBucket = allSpendByBucket;
      _materialOnlyByBucket = materialOnlyByBucket;

      _dailyProjectIds = sortedProjectIds;
      _dailyProjectNames = sortedProjectIds
          .map((id) => projectIdToName[id] ?? id)
          .toList();
      _dailyProjectColors = sortedProjectIds.map(_colorForProjectId).toList();
      _dailyStacksByDay = dailyStacksByDay;
      _dailyBarLabels = dailyBarLabels;

      final totalProj = projectTotals.values.fold(0.0, (a, b) => a + b);
      final projEntries =
          projectTotals.entries.where((e) => e.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      _projectBreakdown = List<Map<String, dynamic>>.generate(
        projEntries.length,
        (i) {
          final e = projEntries[i];
          final pct = totalProj > 0 ? e.value / totalProj : 0.0;
          return {
            'label': projectIdToName[e.key] ?? e.key,
            'amount': e.value,
            'percentage': pct,
            'color': _colorForProjectId(e.key),
            'pctLabel': totalProj > 0 ? '${(pct * 100).round()}%' : '0%',
          };
        },
      );

      final totalCat = categoryTotals.values.fold(0.0, (a, b) => a + b);
      var idx = 0;
      _categoryBreakdown =
          categoryTotals.entries.map((e) {
            final pct = totalCat > 0 ? e.value / totalCat : 0.0;
            final color = _categoryColors[idx % _categoryColors.length];
            idx++;
            return {
              'label': e.key,
              'amount': e.value,
              'percentage': pct,
              'color': color,
              'pctLabel': totalCat > 0 ? '${(pct * 100).round()}%' : '0%',
            };
          }).toList()..sort(
            (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
          );

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);
    final reportTitle =
        widget.projectName ??
        (widget.projectId == null ? 'All Projects' : 'Project Report');

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with Glass Effect
            _buildHeader(isDark, theme, reportTitle),

            // Scrollable Content
            Expanded(
              child: _loading
                  ? _buildLoadingIndicator()
                  : _error != null
                  ? _buildErrorWidget()
                  : RefreshIndicator(
                      onRefresh: _loadReportData,
                      color: AppColors.primary,
                      backgroundColor: isDark
                          ? AppColors.darkCard
                          : Colors.white,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 4),

                            // Time period (sheet + quick presets)
                            _buildPeriodSelector(isDark),

                            const SizedBox(height: 12),

                            // Key Metrics Cards (Fixed RenderFlex issue)
                            _buildMetricsCards(isDark, currency),

                            const SizedBox(height: 24),

                            _buildSpendOverviewLineChart(isDark, currency),

                            const SizedBox(height: 24),

                            if (_projectBreakdown.isNotEmpty) ...[
                              _buildProjectPie(isDark, currency),
                              const SizedBox(height: 24),
                            ],

                            // Materials — spending trend (lines per material line item)
                            _buildMaterialSpendingTrendChart(isDark, currency),

                            const SizedBox(height: 24),

                            if (_categoryBreakdown.isNotEmpty) ...[
                              _buildCategoryDistributionChart(
                                isDark,
                                currency,
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Daily spending — stacked by project (up to 14 days in range)
                            if (_dailyStacksByDay.any(
                              (day) => day.any((v) => v > 0),
                            ))
                              _buildDailyProjectStackedChart(isDark, currency),

                            if (_dailyStacksByDay.any(
                              (day) => day.any((v) => v > 0),
                            ))
                              const SizedBox(height: 24),

                            if (_categoryBreakdown.isNotEmpty)
                              _buildExpenseCategory(isDark, currency),

                            const SizedBox(height: 24),

                            // Task Completion & Budget
                            _buildTaskAndBudget(isDark, currency),

                            const SizedBox(height: 24),

                            // Insights panel
                            _buildInsightsPanel(isDark),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ThemeData theme, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EnterpriseUi.padH, vertical: 10),
      decoration: BoxDecoration(
        color: EnterpriseUi.appBarBg(isDark),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              onPressed: () => context.go(AppRoutes.home),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.lightBorder,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.ios_share_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: _showShareOptions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading your reports...',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadReportData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards(bool isDark, CurrencyProvider currency) {
    final chipBg =
        isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100;
    const chipIcon = AppColors.primary;
    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: EnterpriseUi.padH),
        itemCount: 3,
        itemBuilder: (context, index) {
          Widget card;
          switch (index) {
            case 0:
              card = _buildMetricCard(
                isDark: isDark,
                icon: Icons.payments_rounded,
                iconColor: chipIcon,
                bgColor: chipBg,
                label: 'Spend (period)',
                value: currency.format(_periodSpent),
                trendIcon: Icons.event_rounded,
                trendColor: AppColors.primary,
                trendValue:
                    '$_expenseCountInPeriod entries · ${_friendlyPeriodHeadline()}',
              );
              break;
            case 1:
              card = _buildMetricCard(
                isDark: isDark,
                icon: Icons.account_balance_wallet_rounded,
                iconColor: chipIcon,
                bgColor: chipBg,
                label: 'Remaining',
                value: currency.format(_remaining),
                trendIcon: _remaining >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                trendColor: _remaining >= 0
                    ? AppColors.success
                    : AppColors.error,
                trendValue: _totalBudget > 0
                    ? '${(_remaining / _totalBudget * 100).round()}% left'
                    : '—',
              );
              break;
            case 2:
              card = _buildMetricCard(
                isDark: isDark,
                icon: Icons.pending_actions_rounded,
                iconColor: chipIcon,
                bgColor: chipBg,
                label: 'Tasks',
                value: '$_taskTotal',
                trendIcon: Icons.check_circle_rounded,
                trendColor: AppColors.success,
                trendValue: _taskTotal > 0
                    ? '$_taskDone done · $_taskActive active'
                        '${_taskOverdue > 0 ? ' · $_taskOverdue overdue' : ''}'
                    : 'No tasks',
              );
              break;
            default:
              card = const SizedBox();
          }
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: card,
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required IconData trendIcon,
    required Color trendColor,
    required String trendValue,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and Label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Trend
          Row(
            children: [
              Icon(trendIcon, color: trendColor, size: 14),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  trendValue,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: trendColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Total recorded spend vs materials-only (same buckets as material detail chart).
  Widget _buildSpendOverviewLineChart(bool isDark, CurrencyProvider currency) {
    var allPts = _ensureMinTwoChartPoints(List<double>.from(_allSpendByBucket));
    var matPts = _ensureMinTwoChartPoints(List<double>.from(_materialOnlyByBucket));
    while (allPts.length < matPts.length) {
      allPts.add(0);
    }
    while (matPts.length < allPts.length) {
      matPts.add(0);
    }
    final pointCount = allPts.length;
    final xLabels = _alignXLabels(_materialTrendXLabels, pointCount);

    final hasData = _allSpendByBucket.isNotEmpty &&
        (_allSpendByBucket.any((v) => v > 0) ||
            _materialOnlyByBucket.any((v) => v > 0));
    double maxY = 1;
    if (hasData) {
      for (var i = 0; i < pointCount; i++) {
        final a = i < allPts.length ? allPts[i] : 0.0;
        final b = i < matPts.length ? matPts[i] : 0.0;
        if (a > maxY) maxY = a;
        if (b > maxY) maxY = b;
      }
    }
    final totalMaterials = _materialOnlyByBucket.fold(0.0, (a, b) => a + b);
    final totalAll = _allSpendByBucket.fold(0.0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppColors.lightBorder,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spend vs materials',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All categories (solid) vs Materials only (dashed) · ${_friendlyDateRangeLine()}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(totalAll),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      'Mat. ${currency.format(totalMaterials)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No expenses in this period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: _lineChartMaxX(pointCount),
                    minY: 0,
                    maxY: _safeChartMax(maxY),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          maxY > 0 ? math.max(maxY / 4, 1e-6) : 1,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: isDark ? Colors.white10 : Colors.black12,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (v, m) => Text(
                            _formatAxisYLabel(v),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (v, m) {
                            final i = _axisXIndex(v, xLabels.length);
                            if (i == null ||
                                !_shouldShowXAxisLabel(i, xLabels.length)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                xLabels[i],
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < pointCount; i++)
                                FlSpot(i.toDouble(), allPts[i]),
                            ],
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (s, p, bar, index) =>
                                  FlDotCirclePainter(
                                radius: 3,
                                color: AppColors.primary,
                                strokeWidth: 1.5,
                                strokeColor: isDark
                                    ? AppColors.darkCard
                                    : Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.primary.withOpacity(0.2),
                                  AppColors.primary.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < pointCount; i++)
                                FlSpot(i.toDouble(), matPts[i]),
                            ],
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: AppColors.secondary,
                            barWidth: 2.5,
                            dashArray: [6, 4],
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            final label = s.barIndex == 0
                                ? 'All spend'
                                : 'Materials';
                            return LineTooltipItem(
                              '$label\n${currency.format(s.y)}',
                              TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _overviewLegendRow(
                    isDark,
                    AppColors.primary,
                    'All project spend',
                  ),
                  _overviewLegendRow(
                    isDark,
                    AppColors.secondary,
                    'Materials (actual)',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _overviewLegendRow(bool isDark, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialSpendingTrendChart(
    bool isDark,
    CurrencyProvider currency,
  ) {
    final hasData =
        _materialTrendSeries.isNotEmpty &&
        _materialTrendSeries.any((s) => s.any((v) => v > 0));
    double maxY = 1;
    if (hasData) {
      for (final s in _materialTrendSeries) {
        for (final v in s) {
          if (v > maxY) maxY = v;
        }
      }
    }

    final paddedMaterialSeries = _materialTrendSeries
        .map((s) => _ensureMinTwoChartPoints(List<double>.from(s)))
        .toList();
    final materialTrendPointCount =
        paddedMaterialSeries.isEmpty ? 0 : paddedMaterialSeries.first.length;
    final materialTrendXLabelsAligned =
        _alignXLabels(_materialTrendXLabels, materialTrendPointCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppColors.lightBorder,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material spending (by line item)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Materials category · each line is a material · ${_friendlyDateRangeLine()}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(_periodSpent),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      'All categories (period)',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No material expenses in this period.\nUse Daily Material Entry to log items.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: _lineChartMaxX(materialTrendPointCount),
                    minY: 0,
                    maxY: _safeChartMax(maxY),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          maxY > 0 ? math.max(maxY / 3, 1e-6) : 1,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: isDark ? Colors.white12 : Colors.black12,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (v, m) => Text(
                            _formatAxisYLabel(v),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (v, m) {
                            final i = _axisXIndex(
                              v,
                              materialTrendXLabelsAligned.length,
                            );
                            if (i == null ||
                                !_shouldShowXAxisLabel(
                                  i,
                                  materialTrendXLabelsAligned.length,
                                )) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                materialTrendXLabelsAligned[i],
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      for (var mi = 0; mi < _materialTrendNames.length; mi++)
                        LineChartBarData(
                          spots: [
                            for (var i = 0;
                                i < paddedMaterialSeries[mi].length;
                                i++)
                              FlSpot(
                                i.toDouble(),
                                paddedMaterialSeries[mi][i],
                              ),
                          ],
                          color: _materialLineColors[mi],
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (s, p, bar, index) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: _materialLineColors[mi],
                              strokeWidth: 1,
                              strokeColor: isDark
                                  ? AppColors.darkCard
                                  : Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            final mi = s.barIndex;
                            final name = mi < _materialTrendNames.length
                                ? _materialTrendNames[mi]
                                : '';
                            return LineTooltipItem(
                              '$name\n${currency.format(s.y)}',
                              TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _materialTrendNames.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _materialLineColors[i],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            _materialTrendNames[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProjectStackedChart(
    bool isDark,
    CurrencyProvider currency,
  ) {
    final n = _dailyBarLabels.length;
    if (n == 0) return const SizedBox.shrink();

    double maxTotal = 1;
    for (final day in _dailyStacksByDay) {
      final t = day.fold(0.0, (a, b) => a + b);
      if (t > maxTotal) maxTotal = t;
    }

    // Only show projects that appear in the window
    final activeIdx = <int>[];
    for (var p = 0; p < _dailyProjectIds.length; p++) {
      if (_dailyStacksByDay.any((day) => day[p] > 0)) activeIdx.add(p);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Daily spending by project',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stacked per day (same colors as project breakdown) · up to 14 days',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _safeChartMax(maxTotal),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  horizontalInterval:
                      maxTotal > 0 ? math.max(maxTotal / 3, 1e-6) : 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: isDark ? Colors.white12 : Colors.black12,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) => Text(
                        _formatAxisYLabel(v),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = _axisXIndex(v, n);
                        if (i == null || !_shouldShowXAxisLabel(i, n)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _dailyBarLabels[i],
                            style: TextStyle(
                              fontSize: 8,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                  barGroups: List.generate(n, (i) {
                    final day = _dailyStacksByDay[i];
                    double acc = 0;
                    final items = <BarChartRodStackItem>[];
                    for (final p in activeIdx) {
                      final amt = day[p];
                      if (amt <= 0) continue;
                      final from = acc;
                      acc += amt;
                      items.add(
                        BarChartRodStackItem(from, acc, _dailyProjectColors[p]),
                      );
                    }
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: acc > 0 ? acc : 0.01,
                          width: math.min(18, 200 / n),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          rodStackItems: items.isEmpty
                              ? [
                                  BarChartRodStackItem(
                                    0,
                                    0.01,
                                    Colors.transparent,
                                  ),
                                ]
                              : items,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _safeChartMax(maxTotal),
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.05),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                duration: Duration.zero,
              ),
            ),
            if (activeIdx.length <= 8) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  for (final p in activeIdx)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _dailyProjectColors[p],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            _dailyProjectNames[p],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPie(bool isDark, CurrencyProvider currency) {
    final top = _projectBreakdown.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final total = top.fold<double>(0, (a, m) => a + (m['amount'] as double));
    if (total <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final legend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending by project',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Share of period spend · tap a slice',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final m in top.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: m['color'] as Color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (m['color'] as Color).withOpacity(0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        m['pctLabel'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currency.format(m['amount'] as double),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

          final chart = SizedBox(
            width: double.infinity,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 1.5,
                    centerSpaceRadius: 52,
                    sections: [
                      for (final m in top)
                        PieChartSectionData(
                          color: (m['color'] as Color).withOpacity(0.9),
                          value: m['amount'] as double,
                          title: total > 0 &&
                                  (m['amount'] as double) / total >= 0.06
                              ? '${(((m['amount'] as double) / total) * 100).round()}%'
                              : '',
                          radius: 58,
                          titleStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.lightText,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          titlePositionPercentageOffset: 0.58,
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkCard
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(total),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.lightBorder,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [chart, const SizedBox(height: 16), legend],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: chart),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: legend),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseCategory(bool isDark, CurrencyProvider currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses by Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 20),

            if (_categoryBreakdown.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No expenses recorded yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Show top 5 categories
                  for (int i = 0; i < _categoryBreakdown.length && i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCategoryRow(
                        isDark,
                        _categoryBreakdown[i],
                        currency,
                      ),
                    ),
                  if (_categoryBreakdown.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${_categoryBreakdown.length - 5} more categories',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistributionChart(
    bool isDark,
    CurrencyProvider currency,
  ) {
    final total = _categoryBreakdown.fold<double>(
      0,
      (sum, item) => sum + (item['amount'] as double),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Category distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                Text(
                  currency.format(total),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'A quick view of where the selected-period spend is going.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 18),
            for (int i = 0; i < _categoryBreakdown.length && i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildCategoryBarRow(
                  isDark,
                  _categoryBreakdown[i],
                  currency,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBarRow(
    bool isDark,
    Map<String, dynamic> category,
    CurrencyProvider currency,
  ) {
    final percentage = (category['percentage'] as double).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category['label'] as String,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              category['pctLabel'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: category['color'] as Color,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              currency.format(category['amount'] as double),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(
              0.08,
            ),
            valueColor: AlwaysStoppedAnimation<Color>(
              category['color'] as Color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    bool isDark,
    Map<String, dynamic> category,
    CurrencyProvider currency,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: category['color'] as Color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            category['label'] as String,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            category['pctLabel'] as String,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          currency.format(category['amount'] as double),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskAndBudget(bool isDark, CurrencyProvider currency) {
    final taskPct = _taskTotal > 0 ? (_taskDone / _taskTotal) : 0.0;
    final budgetPct = _totalBudget > 0
        ? (_allTimeSpent / _totalBudget).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Task Progress
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Task Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _taskTotal > 0
                            ? '${(taskPct * 100).round()}% Complete'
                            : 'No Tasks',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _taskTotal > 0 ? taskPct : null,
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.success,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTaskStat(
                      isDark: isDark,
                      count: _taskDone,
                      label: 'Completed',
                      color: AppColors.success,
                    ),
                    _buildTaskStat(
                      isDark: isDark,
                      count: _taskActive,
                      label: 'Active',
                      color: AppColors.warning,
                    ),
                    _buildTaskStat(
                      isDark: isDark,
                      count: _taskTodo,
                      label: 'Backlog',
                      color: AppColors.info,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Budget Progress
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budget Usage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (budgetPct > 0.8
                                    ? AppColors.warning
                                    : AppColors.success)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _totalBudget > 0
                            ? '${(budgetPct * 100).round()}% Used'
                            : 'No Budget',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: budgetPct > 0.8
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _totalBudget > 0 ? budgetPct : null,
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      budgetPct > 0.8 ? AppColors.warning : AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spent (all-time): ${currency.format(_allTimeSpent)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      'Remaining: ${currency.format(_remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _remaining >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStat({
    required bool isDark,
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsPanel(bool isDark) {
    final cards = <Widget>[];

    if (_totalBudget > 0 && _remaining < _totalBudget * 0.2) {
      cards.add(
        _insightCard(
          isDark: isDark,
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          title: 'Budget alert',
          body:
              "You've used ${(_allTimeSpent / _totalBudget * 100).round()}% of allocated budget. Review remaining spend.",
        ),
      );
    }

    if (_missingReceiptCount > 0) {
      cards.add(
        _insightCard(
          isDark: isDark,
          color: AppColors.error,
          icon: Icons.receipt_long_rounded,
          title: 'Missing receipts',
          body:
              '$_missingReceiptCount expense${_missingReceiptCount == 1 ? '' : 's'} in this period have no receipt attached.',
        ),
      );
    }

    if (_pendingReviewCount > 0) {
      cards.add(
        _insightCard(
          isDark: isDark,
          color: AppColors.warning,
          icon: Icons.rate_review_rounded,
          title: 'Needs review',
          body:
              '$_pendingReviewCount receipt${_pendingReviewCount == 1 ? '' : 's'} were saved with low OCR confidence and need review.',
        ),
      );
    }

    if (_repeatPurchaseGroups > 0) {
      cards.add(
        _insightCard(
          isDark: isDark,
          color: AppColors.info,
          icon: Icons.copy_all_rounded,
          title: 'Repeat / near-duplicate purchases',
          body:
              '$_repeatPurchaseGroups group${_repeatPurchaseGroups == 1 ? '' : 's'} '
              '($_repeatPurchaseCount items) look almost identical — same merchant, amount, and date.',
        ),
      );
    }

    if (_taskOverdue > 0) {
      cards.add(
        _insightCard(
          isDark: isDark,
          color: AppColors.error,
          icon: Icons.event_busy_rounded,
          title: 'Overdue tasks',
          body:
              '$_taskOverdue task${_taskOverdue == 1 ? '' : 's'} are past due and still open.',
        ),
      );
    }

    if (cards.isEmpty) {
      cards.add(
        _insightCard(
          isDark: isDark,
          color: AppColors.success,
          icon: Icons.verified_rounded,
          title: 'Looking healthy',
          body:
              'No budget, receipt, duplicate, or overdue-task alerts for this period.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 12),
          ...cards.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: c,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
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
        ],
      ),
    );
  }

  Widget _buildInsightsAlert(bool isDark) {
    return _buildInsightsPanel(isDark);
  }

  void _showShareOptions() {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
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
            const SizedBox(height: 20),
            const Text(
              'Backup & Export',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Export as PDF'),
              subtitle: const Text('Summary PDF for this report range'),
              onTap: () async {
                Navigator.pop(context);
                final savedName = await ExportService.instance.exportReportPdf(
                  title: 'ProjectRack Report',
                  periodLabel: _periodLabelForExport(),
                  metrics: {
                    'Budget': currency.format(_totalBudget),
                    'Spent (period)': currency.format(_periodSpent),
                    'Spent (all-time)': currency.format(_allTimeSpent),
                    'Remaining': currency.format(_remaining),
                    'Entries': _expenseCountInPeriod,
                    'Tasks done': _taskDone,
                    'Tasks active': _taskActive,
                    'Tasks todo': _taskTodo,
                  },
                  categoryBreakdown: _categoryBreakdown,
                  projectBreakdown: _projectBreakdown,
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
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: AppColors.success,
                ),
              ),
              title: const Text('Export as CSV'),
              subtitle: const Text('Compact category and project totals'),
              onTap: () async {
                Navigator.pop(context);
                final savedName = await ExportService.instance.exportReportCsv(
                  title: 'ProjectRack Report',
                  periodLabel: _periodLabelForExport(),
                  metrics: {
                    'Budget': currency.format(_totalBudget),
                    'Spent (period)': currency.format(_periodSpent),
                    'Spent (all-time)': currency.format(_allTimeSpent),
                    'Remaining': currency.format(_remaining),
                    'Entries': _expenseCountInPeriod,
                    'Tasks done': _taskDone,
                    'Tasks active': _taskActive,
                    'Tasks todo': _taskTodo,
                  },
                  categoryBreakdown: _categoryBreakdown,
                  projectBreakdown: _projectBreakdown,
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
