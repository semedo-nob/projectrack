import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/constants/models/activity_model.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class ProjectScheduleScreen extends StatefulWidget {
  const ProjectScheduleScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<ProjectScheduleScreen> createState() => _ProjectScheduleScreenState();
}

class _ProjectScheduleScreenState extends State<ProjectScheduleScreen> {
  Future<void> _addMilestone() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? dueDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return AlertDialog(
              title: const Text('Add milestone'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Milestone title *',
                      hintText: 'e.g. Foundation complete, Harvest start',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dueDate == null
                          ? 'Set due date'
                          : DateFormat('MMM d, yyyy').format(dueDate!),
                    ),
                    trailing: const Icon(Icons.event_rounded),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (d != null) setModal(() => dueDate = d);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    final db = context.read<DriftDatabaseProvider>();
    final existing = await db.getProjectMilestones(widget.projectId);
    await db.createMilestone(
      id: 'ms_${DateTime.now().millisecondsSinceEpoch}',
      projectId: widget.projectId,
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      dueDate: dueDate,
      sortOrder: existing.length,
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
        title: Text('${widget.projectName} · Schedule'),
      ),
      floatingActionButton: EnterpriseUi.primaryFab(
        onPressed: _addMilestone,
        icon: Icons.flag_rounded,
        tooltip: 'Add milestone',
      ),
      body: StreamBuilder<List<ProjectMilestone>>(
        stream: db.watchProjectMilestones(widget.projectId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final done = items.where((m) => m.status == MilestoneStatus.done).length;
          final overdue = items.where((m) => m.isOverdue).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: EnterpriseUi.cardDecoration(isDark),
                child: Row(
                  children: [
                    _stat('Total', '${items.length}', AppColors.info),
                    _stat('Done', '$done', AppColors.success),
                    _stat('Overdue', '$overdue', AppColors.error),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 56,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No milestones yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track project phases and deadlines to stay on schedule.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...items.map((m) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: EnterpriseUi.cardDecoration(isDark).copyWith(
                      border: Border.all(
                        color: m.isOverdue
                            ? AppColors.error.withOpacity(0.5)
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: m.status == MilestoneStatus.done,
                          onChanged: (v) {
                            db.updateMilestoneStatus(
                              id: m.id,
                              status: v == true ? 'done' : 'pending',
                            );
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: m.status == MilestoneStatus.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              Text(
                                m.dueDate == null
                                    ? m.status.displayName
                                    : '${DateFormat('MMM d, yyyy').format(m.dueDate!)} · ${m.status.displayName}'
                                        '${m.isOverdue ? ' · Overdue' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: m.isOverdue
                                      ? AppColors.error
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => db.deleteMilestone(m.id),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
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
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
