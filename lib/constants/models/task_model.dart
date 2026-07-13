import 'package:flutter/material.dart';
import 'package:projectrack1/database/database.dart' as db;
import 'package:projectrack1/themes/app_colors.dart';

enum TaskStatus {
  pending,
  inProgress,
  done,
  blocked;

  String get storageValue {
    switch (this) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.done:
        return 'done';
      case TaskStatus.blocked:
        return 'blocked';
    }
  }

  String get displayName {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
      case TaskStatus.blocked:
        return 'Blocked';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.pending:
        return AppColors.warning;
      case TaskStatus.inProgress:
        return AppColors.info;
      case TaskStatus.done:
        return AppColors.success;
      case TaskStatus.blocked:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.pending:
        return Icons.hourglass_empty_rounded;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case TaskStatus.done:
        return Icons.check_circle_rounded;
      case TaskStatus.blocked:
        return Icons.block_rounded;
    }
  }

  static TaskStatus fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'in_progress':
      case 'in progress':
        return TaskStatus.inProgress;
      case 'done':
      case 'completed':
        return TaskStatus.done;
      case 'blocked':
        return TaskStatus.blocked;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }

  static const List<TaskStatus> all = TaskStatus.values;
}

enum TaskPriority {
  low,
  medium,
  high;

  String get storageValue => name;

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return AppColors.info;
      case TaskPriority.medium:
        return AppColors.warning;
      case TaskPriority.high:
        return AppColors.error;
    }
  }

  static TaskPriority fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  static const List<TaskPriority> all = TaskPriority.values;
}

class ProjectTask {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.done) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final now = DateTime(today.year, today.month, today.day);
    return due.isBefore(now);
  }

  factory ProjectTask.fromDrift(db.Task row) {
    return ProjectTask(
      id: row.id,
      projectId: row.projectId,
      title: row.title,
      description: row.description,
      status: TaskStatus.fromString(row.status),
      priority: TaskPriority.fromString(row.priority),
      dueDate: row.dueDate,
      assignedTo: row.assignedTo,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ProjectTask copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    String? assignedTo,
    bool clearDueDate = false,
    bool clearAssignedTo = false,
    bool clearDescription = false,
    DateTime? updatedAt,
  }) {
    return ProjectTask(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
