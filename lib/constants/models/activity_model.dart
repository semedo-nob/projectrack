import 'package:flutter/material.dart';
import 'package:projectrack1/database/database.dart' as db;
import 'package:projectrack1/themes/app_colors.dart';

enum ActivityType {
  labour,
  site,
  delivery,
  inspection,
  other;

  String get storageValue => name;

  String get displayName {
    switch (this) {
      case ActivityType.labour:
        return 'Labour';
      case ActivityType.site:
        return 'Site work';
      case ActivityType.delivery:
        return 'Delivery';
      case ActivityType.inspection:
        return 'Inspection';
      case ActivityType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.labour:
        return Icons.engineering_rounded;
      case ActivityType.site:
        return Icons.foundation_rounded;
      case ActivityType.delivery:
        return Icons.local_shipping_rounded;
      case ActivityType.inspection:
        return Icons.fact_check_rounded;
      case ActivityType.other:
        return Icons.event_note_rounded;
    }
  }

  static ActivityType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'labour':
      case 'labor':
        return ActivityType.labour;
      case 'site':
        return ActivityType.site;
      case 'delivery':
        return ActivityType.delivery;
      case 'inspection':
        return ActivityType.inspection;
      default:
        return ActivityType.other;
    }
  }

  static const List<ActivityType> all = ActivityType.values;
}

class ProjectActivity {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final ActivityType activityType;
  final DateTime occurredAt;
  final double? hoursSpent;
  final String? performedBy;
  final String? location;
  final String? linkedExpenseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectActivity({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.activityType,
    required this.occurredAt,
    this.hoursSpent,
    this.performedBy,
    this.location,
    this.linkedExpenseId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectActivity.fromDrift(db.ActivityLogRow row) {
    return ProjectActivity(
      id: row.id,
      projectId: row.projectId,
      title: row.title,
      description: row.description,
      activityType: ActivityType.fromString(row.activityType),
      occurredAt: row.occurredAt,
      hoursSpent: row.hoursSpent,
      performedBy: row.performedBy,
      location: row.location,
      linkedExpenseId: row.linkedExpenseId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

enum MilestoneStatus {
  pending,
  done,
  skipped;

  String get storageValue => name;

  String get displayName {
    switch (this) {
      case MilestoneStatus.pending:
        return 'Pending';
      case MilestoneStatus.done:
        return 'Done';
      case MilestoneStatus.skipped:
        return 'Skipped';
    }
  }

  Color get color {
    switch (this) {
      case MilestoneStatus.pending:
        return AppColors.warning;
      case MilestoneStatus.done:
        return AppColors.success;
      case MilestoneStatus.skipped:
        return AppColors.info;
    }
  }

  static MilestoneStatus fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'done':
      case 'completed':
        return MilestoneStatus.done;
      case 'skipped':
        return MilestoneStatus.skipped;
      default:
        return MilestoneStatus.pending;
    }
  }
}

class ProjectMilestone {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final MilestoneStatus status;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectMilestone({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    this.dueDate,
    required this.status,
    required this.sortOrder,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue {
    if (dueDate == null || status == MilestoneStatus.done) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final now = DateTime(today.year, today.month, today.day);
    return due.isBefore(now);
  }

  factory ProjectMilestone.fromDrift(db.ProjectMilestoneRow row) {
    return ProjectMilestone(
      id: row.id,
      projectId: row.projectId,
      title: row.title,
      description: row.description,
      dueDate: row.dueDate,
      status: MilestoneStatus.fromString(row.status),
      sortOrder: row.sortOrder,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
