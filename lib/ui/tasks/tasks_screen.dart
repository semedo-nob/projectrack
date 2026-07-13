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

  List<ProjectTask> _applyFilter(List<ProjectTask> tasks) {
    if (_filter == 'all') return tasks;
    if (_filter == 'overdue') {
      return tasks.where((t) => t.isOverdue).toList();
    }
    return tasks
        .where((t) => t.status.storageValue == _filter)
        .toList();
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
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

                final filtered = _applyFilter(snapshot.data!);
                if (filtered.isEmpty) {
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
                            _filter == 'all'
                                ? 'No tasks yet'
                                : 'No tasks in this filter',
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
                          if (_filter == 'all')
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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
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
