import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/constants/models/task_model.dart';

void main() {
  group('TaskStatus', () {
    test('fromString normalizes common variants', () {
      expect(TaskStatus.fromString('pending'), TaskStatus.pending);
      expect(TaskStatus.fromString('in_progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('In Progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('done'), TaskStatus.done);
      expect(TaskStatus.fromString('completed'), TaskStatus.done);
      expect(TaskStatus.fromString('blocked'), TaskStatus.blocked);
    });

    test('storageValue is stable for DB', () {
      expect(TaskStatus.pending.storageValue, 'pending');
      expect(TaskStatus.inProgress.storageValue, 'in_progress');
      expect(TaskStatus.done.storageValue, 'done');
      expect(TaskStatus.blocked.storageValue, 'blocked');
    });
  });

  group('TaskPriority', () {
    test('fromString defaults to medium', () {
      expect(TaskPriority.fromString('high'), TaskPriority.high);
      expect(TaskPriority.fromString('LOW'), TaskPriority.low);
      expect(TaskPriority.fromString('unknown'), TaskPriority.medium);
    });
  });

  group('ProjectTask', () {
    test('isOverdue ignores completed tasks', () {
      final overdueDone = ProjectTask(
        id: '1',
        projectId: 'p',
        title: 'Done late',
        status: TaskStatus.done,
        priority: TaskPriority.medium,
        dueDate: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final overdueOpen = overdueDone.copyWith(status: TaskStatus.pending);
      expect(overdueDone.isOverdue, isFalse);
      expect(overdueOpen.isOverdue, isTrue);
    });
  });
}
