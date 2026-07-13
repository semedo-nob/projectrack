import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/constants/models/task_model.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/routes/app_routes.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/tasks/widgets/task_priority_indicator.dart';
import 'package:projectrack1/ui/tasks/widgets/task_status_badge.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.task,
    this.taskId,
  });

  final String projectId;
  final String projectName;
  final ProjectTask? task;
  final String? taskId;

  bool get isEditing => task != null || (taskId != null && taskId!.isNotEmpty);

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _assigneeController;
  late TaskStatus _status;
  late TaskPriority _priority;
  DateTime? _dueDate;
  bool _saving = false;
  bool _loading = false;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _editingId = t?.id ?? widget.taskId;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _assigneeController = TextEditingController(text: t?.assignedTo ?? '');
    _status = t?.status ?? TaskStatus.pending;
    _priority = t?.priority ?? TaskPriority.medium;
    _dueDate = t?.dueDate;
    if (widget.isEditing && (t == null || t.title.isEmpty) && _editingId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final task = await context.read<DriftDatabaseProvider>().getProjectTask(
      _editingId!,
    );
    if (!mounted) return;
    if (task != null) {
      _editingId = task.id;
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _assigneeController.text = task.assignedTo ?? '';
      _status = task.status;
      _priority = task.priority;
      _dueDate = task.dueDate;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate(bool isDark) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
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
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = context.read<DriftDatabaseProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final assignee = _assigneeController.text.trim();

    final bool ok;
    if (widget.isEditing) {
      final id = _editingId ?? widget.task?.id;
      if (id == null || id.isEmpty) {
        setState(() => _saving = false);
        return;
      }
      ok = await db.updateTask(
        id: id,
        title: title,
        description: description.isEmpty ? null : description,
        clearDescription: description.isEmpty,
        status: _status.storageValue,
        priority: _priority.storageValue,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        assignedTo: assignee.isEmpty ? null : assignee,
        clearAssignedTo: assignee.isEmpty,
      );
    } else {
      ok = await db.createTask(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}',
        projectId: widget.projectId,
        title: title,
        description: description.isEmpty ? null : description,
        status: _status.storageValue,
        priority: _priority.storageValue,
        dueDate: _dueDate,
        assignedTo: assignee.isEmpty ? null : assignee,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(db.error ?? 'Could not save task'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: EnterpriseUi.screenBg(isDark),
      appBar: AppBar(
        backgroundColor: EnterpriseUi.appBarBg(isDark),
        title: Text(widget.isEditing ? 'Edit Task' : 'New Task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.projectName,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _assigneeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Assigned to (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 18),
            EnterpriseUi.sectionLabel('Status', isDark),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TaskStatus.all.map((s) {
                final selected = _status == s;
                return ChoiceChip(
                  label: Text(s.displayName),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = s),
                  selectedColor: s.color.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: selected
                        ? s.color
                        : (isDark
                              ? AppColors.darkText
                              : AppColors.lightText),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            EnterpriseUi.sectionLabel('Priority', isDark),
            Wrap(
              spacing: 8,
              children: TaskPriority.all.map((p) {
                final selected = _priority == p;
                return ChoiceChip(
                  label: Text(p.displayName),
                  selected: selected,
                  onSelected: (_) => setState(() => _priority = p),
                  selectedColor: p.color.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: selected
                        ? p.color
                        : (isDark
                              ? AppColors.darkText
                              : AppColors.lightText),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            EnterpriseUi.sectionLabel('Due date', isDark),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDueDate(isDark),
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      _dueDate == null
                          ? 'Set due date'
                          : DateFormat('MMM d, y').format(_dueDate!),
                    ),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear due date',
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.clear_rounded),
                  ),
                ],
              ],
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  TaskStatusBadge(status: _status),
                  const SizedBox(width: 8),
                  TaskPriorityIndicator(priority: _priority),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Convenience push helpers used by list/detail screens.
Future<bool?> openCreateTask(
  BuildContext context, {
  required String projectId,
  required String projectName,
}) {
  return context.push<bool>(
    AppRoutes.projectTaskCreate.replaceFirst(':id', projectId),
    extra: projectName,
  );
}

Future<bool?> openEditTask(
  BuildContext context, {
  required String projectId,
  required String projectName,
  required ProjectTask task,
}) {
  return context.push<bool>(
    AppRoutes.projectTaskEdit
        .replaceFirst(':id', projectId)
        .replaceFirst(':taskId', task.id),
    extra: {'projectName': projectName, 'task': task},
  );
}
