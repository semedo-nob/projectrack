// lib/providers/drift_database_provider.dart
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:projectrack1/database/database.dart' as drift_db;

import '../constants/models/expense_model.dart';
import '../constants/models/projects_model.dart';
import '../service/google_sync_service.dart';
import '../themes/app_colors.dart';

class DriftDatabaseProvider extends ChangeNotifier {
  late final drift_db.AppDatabase _database;
  bool _isInitialized = false;
  String? _error;

  /// When set, project queries only return rows for this user (local multi-account).
  String? _activeUserId;

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
  Stream<Map<String, dynamic>> get dashboardStatsStream =>
      _dashboardStatsStream;
  Project? get currentProject => _currentProject;
  Expense? get currentExpense => _currentExpense;
  drift_db.Task? get currentTask => _currentTask;
  bool get isLoading => _isLoading;
  String? get activeUserId => _activeUserId;

  /// Call after login/logout/splash so lists and exports are scoped to the session user.
  void setActiveUserId(String? userId) {
    _activeUserId = userId;
    if (_isInitialized) {
      _initializeStreams();
    }
    notifyListeners();
  }

  /// Call after bulk database changes done outside normal CRUD (e.g. full restore).
  void notifyDatabaseChanged() {
    if (_isInitialized) {
      _initializeStreams();
    }
    notifyListeners();
  }

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
    final uid = _activeUserId;
    if (uid == null) {
      _projectsStream = Stream.value(<Project>[]);
      _dashboardStatsStream = Stream.periodic(
        const Duration(seconds: 20),
        (_) => _emptyDashboardStats(),
      );
      return;
    }

    _projectsStream = _database.watchProjectsForUser(uid).asyncMap((
      driftList,
    ) async {
      final tagsByProject = await _database.getTagsForProjects(
        driftList.map((project) => project.id).toList(),
      );
      return driftList
          .map(
            (project) => Project.fromDrift(
              project,
            ).copyWith(tags: tagsByProject[project.id] ?? const []),
          )
          .toList();
    });

    _dashboardStatsStream = Stream.periodic(
      const Duration(seconds: 20),
      (_) => _database.getDashboardStatsForUser(uid),
    ).asyncMap((stats) => stats);
  }

  Map<String, dynamic> _emptyDashboardStats() => {
    'projectCount': 0,
    'totalBudget': 0.0,
    'totalSpent': 0.0,
    'remainingBudget': 0.0,
    'pendingTasks': 0,
  };

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
    List<String> tags = const [],
  }) async {
    final ownerId = _activeUserId;
    if (ownerId == null) {
      _setError('Not signed in');
      return false;
    }
    _setLoading(true);
    try {
      final now = DateTime.now();
      await _database
          .into(_database.projects)
          .insert(
            drift_db.ProjectsCompanion.insert(
              id: id,
              ownerId: drift.Value(ownerId),
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
      await _database.replaceProjectTags(id, tags);
      await _triggerAutoBackup();
      _clearError();
      notifyListeners();
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
      final uid = _activeUserId;
      final projectData = uid == null
          ? null
          : await _database.getProjectForUser(id, uid);
      if (projectData == null) {
        _currentProject = null;
      } else {
        final tags = await _database.getProjectTags(projectData.id);
        _currentProject = Project.fromDrift(projectData).copyWith(tags: tags);
      }
      _clearError();
    } catch (e) {
      _setError('Failed to load project: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Project>> getAllProjects() async {
    final uid = _activeUserId;
    if (uid == null) return [];
    try {
      final projects = await _database.getProjectsForUser(uid);
      final tagsByProject = await _database.getTagsForProjects(
        projects.map((p) => p.id).toList(),
      );
      return projects
          .map(
            (project) => Project.fromDrift(
              project,
            ).copyWith(tags: tagsByProject[project.id] ?? const []),
          )
          .toList();
    } catch (e) {
      _setError('Failed to get projects: $e');
      return [];
    }
  }

  Future<Project?> getCurrentProjectOrNull(String id) async {
    try {
      final uid = _activeUserId;
      if (uid == null) return null;
      final p = await _database.getProjectForUser(id, uid);
      if (p == null) return null;
      final tags = await _database.getProjectTags(p.id);
      return Project.fromDrift(p).copyWith(tags: tags);
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
    List<String>? tags,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      final uid = _activeUserId;
      final existing = uid == null
          ? null
          : await _database.getProjectForUser(id, uid);
      if (existing == null) {
        _setError('Project not found');
        return false;
      }

      await _database.updateProject(
        drift_db.ProjectsCompanion(
          id: drift.Value(id),
          ownerId: drift.Value(existing.ownerId),
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
      if (tags != null) {
        await _database.replaceProjectTags(id, tags);
      }
      await _triggerAutoBackup();
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
    final uid = _activeUserId;
    if (uid == null) return false;
    _setLoading(true);
    try {
      final row = await _database.getProjectForUser(id, uid);
      if (row == null) {
        _setError('Project not found');
        return false;
      }
      await _database.deleteProjectCascade(id);
      await _triggerAutoBackup();
      if (_currentProject?.id == id) {
        _currentProject = null;
      }
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete project: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Project>> searchProjects(String query) async {
    final uid = _activeUserId;
    if (uid == null) return [];
    try {
      final projects = await _database.searchProjects(query, uid);
      final tagsByProject = await _database.getTagsForProjects(
        projects.map((p) => p.id).toList(),
      );
      return projects
          .map(
            (project) => Project.fromDrift(
              project,
            ).copyWith(tags: tagsByProject[project.id] ?? const []),
          )
          .toList();
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
    double? quantityOriginal,
    String? unitOriginal,
    double? quantityBase,
    String? unitBase,
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
          quantityOriginal: drift.Value(quantityOriginal),
          unitOriginal: drift.Value(unitOriginal),
          quantityBase: drift.Value(quantityBase),
          unitBase: drift.Value(unitBase),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _triggerAutoBackup();
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

  /// Realtime stream of expenses for a project. Use for daily logs history etc.
  Stream<List<Expense>> watchExpensesByProjectStream(String projectId) {
    return _database
        .watchExpensesByProject(projectId)
        .map((list) => list.map((e) => Expense.fromDrift(e)).toList());
  }

  /// Returns all expenses across all projects (for receipt gallery, reports, etc.).
  Future<List<Expense>> getAllExpenses() async {
    try {
      final projects = await getAllProjects();
      final all = <Expense>[];
      for (final p in projects) {
        final list = await getExpensesByProject(p.id);
        all.addAll(list);
      }
      all.sort((a, b) => b.date.compareTo(a.date));
      return all;
    } catch (e) {
      _setError('Failed to get expenses: $e');
      return [];
    }
  }

  Future<void> loadExpense(String id) async {
    _setLoading(true);
    try {
      final expenseData = await _database.getExpense(id);
      _currentExpense = expenseData != null
          ? Expense.fromDrift(expenseData)
          : null;
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
    double? quantityOriginal,
    String? unitOriginal,
    double? quantityBase,
    String? unitBase,
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
          quantityOriginal: drift.Value(quantityOriginal ?? existing.quantityOriginal),
          unitOriginal: drift.Value(unitOriginal ?? existing.unitOriginal),
          quantityBase: drift.Value(quantityBase ?? existing.quantityBase),
          unitBase: drift.Value(unitBase ?? existing.unitBase),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(now),
        ),
      );
      await _triggerAutoBackup();
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
      await _triggerAutoBackup();
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
      await _triggerAutoBackup();
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

  Future<int> countTasksForProjects(List<String> projectIds) async {
    try {
      return await _database.countTasksForProjects(projectIds);
    } catch (e) {
      _setError('Failed to count tasks: $e');
      return 0;
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
      await _triggerAutoBackup();
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
      await _triggerAutoBackup();
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
          list.add(
            _notificationMap(
              type: 'budget',
              title: 'No budget set',
              description:
                  "Set a budget for '${project.name}' to track spending.",
              at: project.createdAt,
              projectId: project.id,
              projectName: project.name,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.warning,
              actionLabel: 'Set Budget',
            ),
          );
        }

        // 2) Over budget warning (≥80% of budget used)
        if (project.budget > 0 && project.progress >= 0.8) {
          final pct = (project.progress * 100).round();
          list.add(
            _notificationMap(
              type: 'budget',
              title: pct >= 100 ? 'Over budget' : 'Budget warning',
              description:
                  "'${project.name}' has used $pct% of allocated funds.",
              at: project.updatedAt,
              projectId: project.id,
              projectName: project.name,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.error,
              actionLabel: 'Review Budget',
            ),
          );
        }

        // 3) No log entry in the last 24 hours
        final expenses = await getExpensesByProject(project.id);
        final lastLogAt = expenses.isNotEmpty
            ? expenses.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b)
            : project.startDate;
        if (now.difference(lastLogAt) >= twentyFourHours) {
          list.add(
            _notificationMap(
              type: 'activity',
              title: 'No recent activity',
              description:
                  "No log entry in the last 24 hours for '${project.name}'.",
              at: lastLogAt.add(twentyFourHours),
              projectId: project.id,
              projectName: project.name,
              icon: Icons.schedule_rounded,
              iconColor: AppColors.info,
              actionLabel: 'Add Log',
            ),
          );
        }

        // 4) Tasks due tomorrow or today (project-based)
        final tasks = await getTasksByProject(project.id);
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final todayStart = DateTime(now.year, now.month, now.day);
        for (final task in tasks) {
          final due = task.dueDate;
          if (due == null || task.status == 'Done') continue;
          if ((due.isAfter(todayStart) && due.isBefore(tomorrow)) ||
              (due.year == now.year &&
                  due.month == now.month &&
                  due.day == now.day)) {
            list.add(
              _notificationMap(
                type: 'task',
                title: 'Due soon',
                description:
                    "'${task.title}' in '${project.name}' is due ${_formatDue(due)}.",
                at: due,
                projectId: project.id,
                projectName: project.name,
                icon: Icons.assignment_rounded,
                iconColor: AppColors.primary,
                actionLabel: 'View Task',
              ),
            );
          }
        }
      }

      list.sort(
        (a, b) => (b['_at'] as DateTime).compareTo(a['_at'] as DateTime),
      );
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
    if (diff.inHours < 24 && at.day == now.day)
      return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${at.day}/${at.month}/${at.year}';
  }

  static String _formatDue(DateTime due) {
    final now = DateTime.now();
    if (due.year == now.year && due.month == now.month && due.day == now.day)
      return 'today';
    final tomorrow = now.add(const Duration(days: 1));
    if (due.year == tomorrow.year &&
        due.month == tomorrow.month &&
        due.day == tomorrow.day)
      return 'tomorrow';
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
    final idSeed = [
      type,
      title,
      description,
      projectId,
      projectName,
      at.toIso8601String(),
    ].join('|');
    return {
      'id': idSeed,
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
    final uid = _activeUserId;
    if (uid == null) return _emptyDashboardStats();
    try {
      return await _database.getDashboardStatsForUser(uid);
    } catch (e) {
      _setError('Failed to get dashboard stats: $e');
      return _emptyDashboardStats();
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

  Future<void> _triggerAutoBackup() async {
    final uid = _activeUserId;
    if (uid == null) return;
    try {
      await GoogleSyncService.instance.backupIfEnabled(
        database: _database,
        userId: uid,
      );
    } catch (e) {
      debugPrint('Auto-backup skipped: $e');
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _database.close();
    }
    super.dispose();
  }
}
