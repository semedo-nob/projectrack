import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/constants/models/task_model.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/routes/app_routes.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/tasks/task_form_screen.dart';
import 'package:projectrack1/ui/tasks/widgets/task_card.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'all';
  String _sort = 'due_soon';

  List<ProjectTask> _applyFilter(List<ProjectTask> tasks) {
    Iterable<ProjectTask> filtered = tasks;
    switch (_filter) {
      case 'overdue':
        filtered = tasks.where((t) => t.isOverdue);
        break;
      case 'due_soon':
        filtered = tasks.where((t) {
          if (t.dueDate == null || t.status == TaskStatus.done) return false;
          final due = DateTime(
            t.dueDate!.year,
            t.dueDate!.month,
            t.dueDate!.day,
          );
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final inThree = today.add(const Duration(days: 3));
          return !due.isBefore(today) && !due.isAfter(inThree);
        });
        break;
      case 'high':
        filtered = tasks.where(
          (t) => t.priority == TaskPriority.high && t.status != TaskStatus.done,
        );
        break;
      case 'all':
        break;
      default:
        filtered = tasks.where((t) => t.status.storageValue == _filter);
    }

    final list = filtered.toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'priority':
          final cmp = b.priority.index.compareTo(a.priority.index);
          if (cmp != 0) return cmp;
          return _compareDue(a, b);
        case 'newest':
          return b.createdAt.compareTo(a.createdAt);
        case 'title':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'due_soon':
        default:
          return _compareDue(a, b);
      }
    });
    return list;
  }

  int _compareDue(ProjectTask a, ProjectTask b) {
    // Overdue first, then soonest due, then no due date last.
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    if (a.dueDate == null && b.dueDate == null) {
      return b.updatedAt.compareTo(a.updatedAt);
    }
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    final cmp = a.dueDate!.compareTo(b.dueDate!);
    if (cmp != 0) return cmp;
    return b.priority.index.compareTo(a.priority.index);
  }

  Future<void> _create() async {
    await openCreateTask(
      context,
      projectId: widget.projectId,
      projectName: widget.projectName,
    );
  }

  void _openDetail(ProjectTask task) {
    context.push(
      AppRoutes.projectTaskDetail
          .replaceFirst(':id', widget.projectId)
          .replaceFirst(':taskId', task.id),
      extra: {'projectName': widget.projectName, 'task': task},
    );
  }

  Future<void> _updateStatus(ProjectTask task, TaskStatus status) async {
    await context.read<DriftDatabaseProvider>().updateTask(
      id: task.id,
      status: status.storageValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final db = context.watch<DriftDatabaseProvider>();

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      appBar: AppBar(
        backgroundColor: EnterpriseUi.appBarBg(isDark),
        title: Text('${widget.projectName} · Tasks'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort tasks',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              _sortItem('due_soon', 'Due soon first'),
              _sortItem('priority', 'Priority high → low'),
              _sortItem('newest', 'Newest created'),
              _sortItem('title', 'Title A → Z'),
            ],
          ),
        ],
      ),
      floatingActionButton: EnterpriseUi.primaryFab(
        onPressed: _create,
        icon: Icons.add_rounded,
        tooltip: 'Add task',
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _chip('all', 'All'),
                _chip('pending', 'Pending'),
                _chip('in_progress', 'In Progress'),
                _chip('done', 'Done'),
                _chip('blocked', 'Blocked'),
                _chip('overdue', 'Overdue'),
                _chip('due_soon', 'Due soon'),
                _chip('high', 'High priority'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProjectTask>>(
              stream: db.watchProjectTasks(widget.projectId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;
                final filtered = _applyFilter(all);
                final open = all.where((t) => t.status != TaskStatus.done).length;
                final overdue = all.where((t) => t.isOverdue).length;
                final high = all
                    .where(
                      (t) =>
                          t.priority == TaskPriority.high &&
                          t.status != TaskStatus.done,
                    )
                    .length;
                final done = all.where((t) => t.status == TaskStatus.done).length;

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 56,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No tasks yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track work items for this project — pending jobs, blockers, and due dates.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create first task'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _summaryBar(
                        isDark: isDark,
                        open: open,
                        overdue: overdue,
                        high: high,
                        done: done,
                      );
                    }
                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No tasks in this filter',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    final task = filtered[index - 1];
                    return TaskCard(
                      task: task,
                      isDark: isDark,
                      onTap: () => _openDetail(task),
                      onStatusChanged: (status) =>
                          _updateStatus(task, status),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Text(_sort == value ? '✓ $label' : label),
    );
  }

  Widget _summaryBar({
    required bool isDark,
    required int open,
    required int overdue,
    required int high,
    required int done,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          _stat('Open', '$open', AppColors.info),
          _stat('Overdue', '$overdue', AppColors.error),
          _stat('High', '$high', AppColors.warning),
          _stat('Done', '$done', AppColors.success),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppColors.primary.withOpacity(0.18),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary : null,
        ),
      ),
    );
  }
}
