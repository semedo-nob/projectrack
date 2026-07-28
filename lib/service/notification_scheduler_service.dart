import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../providers/drift_database_provider.dart';

/// Schedules OS-level reminders from the same rules as in-app notifications.
class NotificationSchedulerService {
  NotificationSchedulerService._();
  static final NotificationSchedulerService instance =
      NotificationSchedulerService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // App timezone (East Africa); used for daily check-in schedule.
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }

    _initialized = true;
  }

  Future<void> refreshFromProvider(DriftDatabaseProvider db) async {
    try {
      if (!_initialized) await initialize();
      await _plugin.cancelAll();

      final items = await db.getProjectNotifications();
      var id = 100;
      for (final item in items.take(12)) {
        final title = item['title'] as String? ?? 'ProjectRack';
        final body = item['description'] as String? ?? '';
        await _plugin.show(
          id: id++,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'projectrack_alerts',
              'Project alerts',
              channelDescription:
                  'Budget, schedule, receipt, and activity reminders',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }

      // Morning reminder to log activity (daily at 8:00 local).
      await _plugin.zonedSchedule(
        id: 1,
        title: 'Daily project check-in',
        body:
            "Log today's materials, activities, or receipts to stay on budget and schedule.",
        scheduledDate: _nextInstanceOfHour(8),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'projectrack_daily',
            'Daily reminders',
            channelDescription: 'Daily logging reminders',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Notification schedule skipped: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
