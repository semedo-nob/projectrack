// lib/providers/drift_database_provider.dart
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:projectrack1/database/database.dart' as drift_db; // Use alias instead of hide
import 'package:drift/drift.dart';

import '../constants/models/expense_model.dart';
import '../constants/models/projects_model.dart';
import '../themes/app_colors.dart';

class DriftDatabaseProvider extends ChangeNotifier {
  late final drift_db.AppDatabase _database;
  bool _isInitialized = false;
  String? _error;

  // Reactive streams (mapped to your model classes)
  late Stream<List<Project>> _projectsStream;
  late Stream<Map<String, dynamic>> _dashboardStatsStream;

  // Current selections
  Project? _currentProject;
  Expense? _currentExpense;
  drift_db.Task? _currentTask; // Keep Drift's Task type

  // Loading states
  bool _isLoading = false;

  // Getters
  drift_db.AppDatabase get database => _database;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  Stream<List<Project>> get projectsStream => _projectsStream;
  Stream<Map<String, dynamic>> get dashboardStatsStream => _dashboardStatsStream;
  Project? get currentProject => _currentProject;
  Expense? get currentExpense => _currentExpense;
  drift_db.Task? get currentTask => _currentTask;
  bool get isLoading => _isLoading;

  Future<void> initializeDriftDatabase() async {
    try {
      _database = drift_db.AppDatabase(); // Initialize database
      _initializeStreams();
      _isInitialized = true;
      _error = null;
    } catch (e) {
      _isInitialized = false;
      _error = 'Failed to initialize database: $e';
      debugPrint(_error);
    }
    notifyListeners();
  }

  void _initializeStreams() {
    // Map Drift's Project to your Project model - NO CASTING
    _projectsStream = _database.watchAllProjects().map(
          (driftList) => driftList.map((driftProject) => Project.fromDrift(driftProject)).toList(),
    );

    // Dashboard stats stream
    _dashboardStatsStream = Stream.periodic(
      const Duration(seconds: 1),
          (_) => _database.getDashboardStats(),
    ).asyncMap((stats) => stats);
  }

  // ===== PROJECT METHODS =====

  Future<bool> createProject({
    required String id,
    required String name,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
    required double budget,
    required String status,
    required String category,
    required String imageUrl,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      await _database.into(_database.projects).insert(
        drift_db.ProjectsCompanion.insert(
          id: id,
          name: name,
          description: description,
          startDate: startDate,
          endDate: drift.Value(endDate),
          budget: budget,
          spent: drift.Value(0.0),
          status: status,
          category: category,
          progress: drift.Value(0.0),
          imageUrl: drift.Value(imageUrl),
          createdAt: now,
          updatedAt: now,
        ),
      );
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to create project: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProject(String id) async {
    _setLoading(true);
    try {
      final projectData = await _database.getProject(id);
      _currentProject = projectData != null ? Project.fromDrift(projectData) : null;
      _clearError();
    } catch (e) {
      _setError('Failed to load project: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Project>> getAllProjects() async {
    try {
      final projects = await _database.getAllProjects();
      return projects.map((p) => Project.fromDrift(p)).toList();
    } catch (e) {
      _setError('Failed to get projects: $e');
      return [];
    }
  }

  Future<Project?> getCurrentProjectOrNull(String id) async {
    try {
      final p = await _database.getProject(id);
      return p != null ? Project.fromDrift(p) : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProject({
    required String id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    double? spent,
    String? status,
    String? category,
    double? progress,
    String? imageUrl,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      final existing = await _database.getProject(id);
      if (existing == null) {
        _setError('Project not found');
        return false;
      }

      await _database.updateProject(
        drift_db.ProjectsCompanion(
          id: drift.Value(id),
          name: drift.Value(name ?? existing.name),
          description: drift.Value(description ?? existing.description),
          startDate: drift.Value(startDate ?? existing.startDate),
          endDate: drift.Value(endDate ?? existing.endDate),
          budget: drift.Value(budget ?? existing.budget),
          spent: drift.Value(spent ?? existing.spent),
          status: drift.Value(status ?? existing.status),
          category: drift.Value(category ?? existing.category),
          progress: drift.Value(progress ?? existing.progress),
          imageUrl: drift.Value(imageUrl ?? existing.imageUrl),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(now),
        ),
      );
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to update project: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteProject(String id) async {
    _setLoading(true);
    try {
      await _database.deleteProject(id);
      if (_currentProject?.id == id) {
        _currentProject = null;
      }
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to delete project: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Project>> searchProjects(String query) async {
    try {
      final projects = await _database.searchProjects(query);
      return projects.map((p) => Project.fromDrift(p)).toList();
    } catch (e) {
      _setError('Failed to search projects: $e');
      return [];
    }
  }

  // ===== EXPENSE METHODS =====

  Future<bool> createExpense({
    required String id,
    required String projectId,
    required String merchant,
    required double amount,
    required DateTime date,
    required String category,
    String? notes,
    String? receiptImage,
    required String status,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      await _database.insertExpense(
        drift_db.ExpensesCompanion.insert(
          id: id,
          projectId: projectId,
          merchant: merchant,
          amount: amount,
          date: date,
          category: category,
          notes: drift.Value(notes),
          receiptImage: drift.Value(receiptImage),
          status: status,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to create expense: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Expense>> getExpensesByProject(String projectId) async {
    try {
      final expenses = await _database.getExpensesByProject(projectId);
      return expenses.map((e) => Expense.fromDrift(e)).toList();
    } catch (e) {
      _setError('Failed to get expenses: $e');
      return [];
    }
  }

  Future<void> loadExpense(String id) async {
    _setLoading(true);
    try {
      final expenseData = await _database.getExpense(id);
      _currentExpense = expenseData != null ? Expense.fromDrift(expenseData) : null;
      _clearError();
    } catch (e) {
      _setError('Failed to load expense: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateExpense({
    required String id,
    String? merchant,
    double? amount,
    DateTime? date,
    String? category,
    String? notes,
    String? receiptImage,
    String? status,
  }) async {
    _setLoading(true);
    try {
      final existing = await _database.getExpense(id);
      if (existing == null) {
        _setError('Expense not found');
        return false;
      }

      final now = DateTime.now();
      await _database.updateExpense(
        drift_db.ExpensesCompanion(
          id: drift.Value(id),
          projectId: drift.Value(existing.projectId),
          merchant: drift.Value(merchant ?? existing.merchant),
          amount: drift.Value(amount ?? existing.amount),
          date: drift.Value(date ?? existing.date),
          category: drift.Value(category ?? existing.category),
          notes: drift.Value(notes ?? existing.notes),
          receiptImage: drift.Value(receiptImage ?? existing.receiptImage),
          status: drift.Value(status ?? existing.status),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(now),
        ),
      );
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to update expense: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteExpense(String id) async {
    _setLoading(true);
    try {
      await _database.deleteExpense(id);
      if (_currentExpense?.id == id) {
        _currentExpense = null;
      }
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to delete expense: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== TASK METHODS =====

  Future<bool> createTask({
    required String id,
    required String projectId,
    required String title,
    String? description,
    required String status,
    required String priority,
    DateTime? dueDate,
    String? assignedTo,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      await _database.insertTask(
        drift_db.TasksCompanion.insert(
          id: id,
          projectId: projectId,
          title: title,
          description: drift.Value(description),
          status: status,
          priority: priority,
          dueDate: drift.Value(dueDate),
          assignedTo: drift.Value(assignedTo),
          createdAt: now,
          updatedAt: now,
        ),
      );
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to create task: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<drift_db.Task>> getTasksByProject(String projectId) async {
    try {
      return await _database.getTasksByProject(projectId);
    } catch (e) {
      _setError('Failed to get tasks: $e');
      return [];
    }
  }

  Future<void> loadTask(String id) async {
    _setLoading(true);
    try {
      _currentTask = await _database.getTask(id);
      _clearError();
    } catch (e) {
      _setError('Failed to load task: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateTask({
    required String id,
    String? title,
    String? description,
    String? status,
    String? priority,
    DateTime? dueDate,
    String? assignedTo,
  }) async {
    _setLoading(true);
    try {
      final existing = await _database.getTask(id);
      if (existing == null) {
        _setError('Task not found');
        return false;
      }

      final now = DateTime.now();
      await _database.updateTask(
        drift_db.TasksCompanion(
          id: drift.Value(id),
          projectId: drift.Value(existing.projectId),
          title: drift.Value(title ?? existing.title),
          description: drift.Value(description ?? existing.description),
          status: drift.Value(status ?? existing.status),
          priority: drift.Value(priority ?? existing.priority),
          dueDate: drift.Value(dueDate ?? existing.dueDate),
          assignedTo: drift.Value(assignedTo ?? existing.assignedTo),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(now),
        ),
      );
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to update task: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteTask(String id) async {
    _setLoading(true);
    try {
      await _database.deleteTask(id);
      if (_currentTask?.id == id) {
        _currentTask = null;
      }
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to delete task: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== PROJECT NOTIFICATIONS (real data) =====

  /// Builds notifications from project data: no budget set, 24h without log entry, over budget, tasks due soon.
  Future<List<Map<String, dynamic>>> getProjectNotifications() async {
    final list = <Map<String, dynamic>>[];
    try {
      final projects = await getAllProjects();
      final now = DateTime.now();
      const twentyFourHours = Duration(hours: 24);

      for (final project in projects) {
        // 1) No budget set (created without budget or budget is 0)
        if (project.budget <= 0) {
          list.add(_notificationMap(
            type: 'budget',
            title: 'No budget set',
            description: "Set a budget for '${project.name}' to track spending.",
            at: project.createdAt,
            projectId: project.id,
            projectName: project.name,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.warning,
            actionLabel: 'Set Budget',
          ));
        }

        // 2) Over budget warning (≥80% of budget used)
        if (project.budget > 0 && project.progress >= 0.8) {
          final pct = (project.progress * 100).round();
          list.add(_notificationMap(
            type: 'budget',
            title: pct >= 100 ? 'Over budget' : 'Budget warning',
            description: "'${project.name}' has used $pct% of allocated funds.",
            at: project.updatedAt,
            projectId: project.id,
            projectName: project.name,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.error,
            actionLabel: 'Review Budget',
          ));
        }

        // 3) No log entry in the last 24 hours
        final expenses = await getExpensesByProject(project.id);
        final lastLogAt = expenses.isNotEmpty
            ? expenses.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b)
            : project.startDate;
        if (now.difference(lastLogAt) >= twentyFourHours) {
          list.add(_notificationMap(
            type: 'activity',
            title: 'No recent activity',
            description: "No log entry in the last 24 hours for '${project.name}'.",
            at: lastLogAt.add(twentyFourHours),
            projectId: project.id,
            projectName: project.name,
            icon: Icons.schedule_rounded,
            iconColor: AppColors.info,
            actionLabel: 'Add Log',
          ));
        }

        // 4) Tasks due tomorrow or today (project-based)
        final tasks = await getTasksByProject(project.id);
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final todayStart = DateTime(now.year, now.month, now.day);
        for (final task in tasks) {
          final due = task.dueDate;
          if (due == null || task.status == 'Done') continue;
          if ((due.isAfter(todayStart) && due.isBefore(tomorrow)) ||
              (due.year == now.year && due.month == now.month && due.day == now.day)) {
            list.add(_notificationMap(
              type: 'task',
              title: 'Due soon',
              description: "'${task.title}' in '${project.name}' is due ${_formatDue(due)}.",
              at: due,
              projectId: project.id,
              projectName: project.name,
              icon: Icons.assignment_rounded,
              iconColor: AppColors.primary,
              actionLabel: 'View Task',
            ));
          }
        }
      }

      list.sort((a, b) => (b['_at'] as DateTime).compareTo(a['_at'] as DateTime));
      for (final m in list) {
        m['section'] = _sectionLabel(m['_at'] as DateTime);
        m['time'] = _timeAgo(m['_at'] as DateTime);
        m.remove('_at');
      }
      return list;
    } catch (e) {
      _setError('Failed to load notifications: $e');
      return [];
    }
  }

  static String _sectionLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final atDay = DateTime(at.year, at.month, at.day);
    if (atDay == today) return 'Today';
    if (atDay == yesterday) return 'Yesterday';
    return 'Earlier';
  }

  static String _timeAgo(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24 && at.day == now.day) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${at.day}/${at.month}/${at.year}';
  }

  static String _formatDue(DateTime due) {
    final now = DateTime.now();
    if (due.year == now.year && due.month == now.month && due.day == now.day) return 'today';
    final tomorrow = now.add(const Duration(days: 1));
    if (due.year == tomorrow.year && due.month == tomorrow.month && due.day == tomorrow.day) return 'tomorrow';
    return '${due.day}/${due.month}/${due.year}';
  }

  static Map<String, dynamic> _notificationMap({
    required String type,
    required String title,
    required String description,
    required DateTime at,
    required String projectId,
    required String projectName,
    required IconData icon,
    required Color iconColor,
    String? actionLabel,
  }) {
    return {
      'type': type,
      'title': title,
      'description': description,
      '_at': at,
      'projectId': projectId,
      'projectName': projectName,
      'icon': icon,
      'iconColor': iconColor,
      'iconBgColor': iconColor.withOpacity(0.1),
      'unread': true,
      'action': true,
      'actionLabel': actionLabel ?? 'View',
      'hasChevron': true,
    };
  }

  // ===== DASHBOARD STATS =====

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      return await _database.getDashboardStats();
    } catch (e) {
      _setError('Failed to get dashboard stats: $e');
      return {
        'projectCount': 0,
        'totalBudget': 0.0,
        'totalSpent': 0.0,
        'remainingBudget': 0.0,
        'pendingTasks': 0,
      };
    }
  }

  // ===== UTILITY METHODS =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  Future<void> dispose() async {
    if (_isInitialized) {
      await _database.close();
    }
    super.dispose();
  }
}