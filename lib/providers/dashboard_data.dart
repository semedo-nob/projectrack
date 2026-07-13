import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../constants/models/projects_model.dart';

/// Snapshot of dashboard metrics, rebuilt whenever underlying Drift tables change.
class DashboardData {
  const DashboardData({
    required this.projects,
    required this.projectCount,
    required this.activeProjectCount,
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingBudget,
    required this.pendingTasks,
    required this.doneTasks,
    required this.insightsSeries,
  });

  final List<Project> projects;
  final int projectCount;
  final int activeProjectCount;
  final double totalBudget;
  final double totalSpent;
  final double remainingBudget;
  final int pendingTasks;
  final int doneTasks;
  final List<DashboardInsightSeries> insightsSeries;

  List<Project> get recentProjects => projects.take(5).toList();

  static DashboardData empty() => const DashboardData(
    projects: [],
    projectCount: 0,
    activeProjectCount: 0,
    totalBudget: 0,
    totalSpent: 0,
    remainingBudget: 0,
    pendingTasks: 0,
    doneTasks: 0,
    insightsSeries: [],
  );

  /// Compatibility map for older call sites that still expect Map stats.
  Map<String, dynamic> toStatsMap() => {
    'projectCount': projectCount,
    'totalBudget': totalBudget,
    'totalSpent': totalSpent,
    'remainingBudget': remainingBudget,
    'pendingTasks': pendingTasks,
    'doneTasks': doneTasks,
  };
}

class DashboardInsightSeries {
  const DashboardInsightSeries({
    required this.projectId,
    required this.projectName,
    required this.color,
    required this.spots,
  });

  final String projectId;
  final String projectName;
  final Color color;
  final List<FlSpot> spots;
}
