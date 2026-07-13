import 'package:flutter/material.dart';
import 'package:projectrack1/constants/models/task_model.dart';

class TaskPriorityIndicator extends StatelessWidget {
  const TaskPriorityIndicator({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priority.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: priority.color,
        ),
      ),
    );
  }
}
