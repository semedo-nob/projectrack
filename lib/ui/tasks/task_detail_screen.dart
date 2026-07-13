import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/constants/models/task_model.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/routes/app_routes.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/tasks/task_form_screen.dart';
import 'package:projectrack1/ui/tasks/widgets/task_priority_indicator.dart';
import 'package:projectrack1/ui/tasks/widgets/task_status_badge.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.taskId,
    this.initialTask,
  });

  final String projectId;
  final String projectName;
  final String taskId;
  final ProjectTask? initialTask;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  ProjectTask? _task;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _task = widget.initialTask;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _task == null;
      _error = null;
    });
    final task = await context.read<DriftDatabaseProvider>().getProjectTask(
      widget.taskId,
    );
    if (!mounted) return;
    setState(() {
      _task = task;
      _loading = false;
      if (task == null) _error = 'Task not found';
    });
  }

  Future<void> _setStatus(TaskStatus status) async {
    final task = _task;
    if (task == null) return;
    final ok = await context.read<DriftDatabaseProvider>().updateTask(
      id: task.id,
      status: status.storageValue,
    );
    if (!mounted) return;
    if (ok) {
      await _load();
    }
  }

  Future<void> _edit() async {
    final task = _task;
    if (task == null) return;
    final changed = await openEditTask(
      context,
      projectId: widget.projectId,
      projectName: widget.projectName,
      task: task,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete() async {
    final task = _task;
    if (task == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context.read<DriftDatabaseProvider>().deleteTask(task.id);
    if (!mounted) return;
    if (ok) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final task = _task;

    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      appBar: AppBar(
        backgroundColor: EnterpriseUi.appBarBg(isDark),
        title: const Text('Task'),
        actions: [
          if (task != null) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: _edit,
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || task == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Task not found'),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.pop(), child: const Text('Back')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.projectName,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TaskStatusBadge(status: task.status),
                    const SizedBox(width: 8),
                    TaskPriorityIndicator(priority: task.priority),
                  ],
                ),
                const SizedBox(height: 20),
                if (task.description != null &&
                    task.description!.trim().isNotEmpty) ...[
                  EnterpriseUi.sectionLabel('Description', isDark),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: EnterpriseUi.cardDecoration(isDark),
                    child: Text(
                      task.description!,
                      style: TextStyle(
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                EnterpriseUi.sectionLabel('Details', isDark),
                Container(
                  decoration: EnterpriseUi.cardDecoration(isDark),
                  child: Column(
                    children: [
                      _detailRow(
                        isDark,
                        Icons.event_rounded,
                        'Due date',
                        task.dueDate == null
                            ? 'Not set'
                            : DateFormat('MMM d, y').format(task.dueDate!),
                        valueColor: task.isOverdue ? AppColors.error : null,
                      ),
                      const Divider(height: 1),
                      _detailRow(
                        isDark,
                        Icons.person_outline_rounded,
                        'Assigned to',
                        task.assignedTo?.trim().isNotEmpty == true
                            ? task.assignedTo!
                            : 'Unassigned',
                      ),
                      const Divider(height: 1),
                      _detailRow(
                        isDark,
                        Icons.schedule_rounded,
                        'Updated',
                        DateFormat('MMM d, y · HH:mm').format(task.updatedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                EnterpriseUi.sectionLabel('Update status', isDark),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskStatus.all.map((s) {
                    final selected = task.status == s;
                    return ChoiceChip(
                      label: Text(s.displayName),
                      selected: selected,
                      onSelected: selected ? null : (_) => _setStatus(s),
                      selectedColor: s.color.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.projectTasks.replaceFirst(':id', widget.projectId),
                    extra: widget.projectName,
                  ),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('All project tasks'),
                ),
              ],
            ),
    );
  }

  Widget _detailRow(
    bool isDark,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ??
                    (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
