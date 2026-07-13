import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/providers/dashboard_data.dart';

void main() {
  test('DashboardData.empty has zeroed metrics', () {
    final empty = DashboardData.empty();
    expect(empty.projectCount, 0);
    expect(empty.totalSpent, 0);
    expect(empty.pendingTasks, 0);
    expect(empty.projects, isEmpty);
    expect(empty.insightsSeries, isEmpty);
    expect(empty.toStatsMap()['pendingTasks'], 0);
  });
}
