import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:projectrack1/constants/models/task_model.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:projectrack1/ui/tasks/widgets/task_priority_indicator.dart';
import 'package:projectrack1/ui/tasks/widgets/task_status_badge.dart';
import 'package:projectrack1/ui/widgets/enterprise_ui.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.onTap,
    required this.onStatusChanged,
  });

  final ProjectTask task;
  final bool isDark;
  final VoidCallback onTap;
  final ValueChanged<TaskStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: EnterpriseUi.cardDecoration(isDark),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EnterpriseUi.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: task.status == TaskStatus.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ),
                    TaskPriorityIndicator(priority: task.priority),
                    PopupMenuButton<TaskStatus>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      onSelected: onStatusChanged,
                      itemBuilder: (context) => TaskStatus.all
                          .map(
                            (s) => PopupMenuItem(
                              value: s,
                              child: Text('Mark as ${s.displayName}'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                if (task.description != null &&
                    task.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    TaskStatusBadge(status: task.status),
                    const SizedBox(width: 8),
                    if (task.dueDate != null) ...[
                      Icon(
                        Icons.event_rounded,
                        size: 14,
                        color: task.isOverdue
                            ? AppColors.error
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y').format(task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: task.isOverdue
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: task.isOverdue
                              ? AppColors.error
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                    if (task.assignedTo != null &&
                        task.assignedTo!.trim().isNotEmpty) ...[
                      const Spacer(),
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          task.assignedTo!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
