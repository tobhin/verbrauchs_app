// lib/services/notification_service.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'logger_service.dart';
import '../models/reminder.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse resp) {
  Logger.log('[NOTIF] BG tap payload=${resp.payload}');
}

class NotificationService {
  static final NotificationService _i = NotificationService._internal();
  factory NotificationService() => _i;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  Future<void> init() async {
    if (_initialized) return;

    await requestPermissions();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'meter_reminders',
        'Zähler-Erinnerungen',
        description: 'Erinnerungen zum Eintragen der Zählerstände',
        importance: Importance.high,
      ),
    );
    await Logger.log('[NOTIF] notification channel created');

    const iOSInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iOSInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
  }

  Future<void> _handleNotificationResponse(NotificationResponse resp) async {
    await Logger.log('[NOTIF] onTap payload=${resp.payload} id=${resp.id}');
  }

  DateTime computeNextFire(RepeatPlan repeat, DateTime base) {
    final now = DateTime.now();
    if (repeat == RepeatPlan.none) {
      return base.isBefore(now) ? now.add(const Duration(days: 365 * 10)) : base;
    }

    DateTime dt = base;

    if (repeat == RepeatPlan.weekly) {
      while (dt.isBefore(now)) {
        dt = dt.add(const Duration(days: 7));
      }
      return dt;
    }

    if (repeat == RepeatPlan.monthly) {
      while (dt.isBefore(now)) {
        var nextMonth = dt.month + 1;
        var nextYear = dt.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        dt = DateTime(nextYear, nextMonth, math.min(dt.day, lastDayOfNextMonth), dt.hour, dt.minute);
      }
      return dt;
    }

    return dt;
  }

  AndroidNotificationDetails _channel() {
    return const AndroidNotificationDetails(
      'meter_reminders',
      'Zähler-Erinnerungen',
      channelDescription: 'Erinnerungen zum Eintragen der Zählerstände',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
  }

  Future<bool> scheduleFlexible({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    DateTimeComponents? matchComponents,
  }) async {
    try {
      await init();

      bool permissionsGranted = await areNotificationsEnabled() && await areExactAlarmsLikelyEnabled();
      if (!permissionsGranted) {
        await Logger.log('[NOTIF][ERR] Permissions not granted for scheduling.');
        return false;
      }

      final tzTime = tz.TZDateTime.from(whenLocal, tz.local);

      if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
        await Logger.log('[NOTIF][WARN] Attempted to schedule in the past. Skipping. id=$id when=$tzTime');
        return false;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(android: _channel()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // MODIFIZIERT: Die folgende Zeile wurde entfernt, da sie in der neuen Paketversion nicht mehr existiert.
        // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: 'meter-reminder',
      );
      await Logger.log('[NOTIF] SCHEDULED id=$id title="$title" when=$tzTime repeat=$matchComponents');
      return true;
    } catch (e, st) {
      await Logger.log('[NOTIF][ERR] ScheduleFlexible failed: $e\n$st');
      return false;
    }
  }

  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
    await Logger.log('[NOTIF] All pending notifications have been cancelled.');
  }

  Future<void> checkPendingNotifications() async {
    if (!_initialized) await init();
    final pendingRequests = await _plugin.pendingNotificationRequests();
    await Logger.log('[DIAGNOSE] Checking for pending notifications...');
    if (pendingRequests.isEmpty) {
      await Logger.log('[DIAGNOSE] No pending notifications found.');
      return;
    }
    for (var p in pendingRequests) {
      await Logger.log('[DIAGNOSE] Found pending notification: id=${p.id}, title="${p.title}", body="${p.body}", payload=${p.payload}');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true;
  }

  Future<bool> areExactAlarmsLikelyEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.scheduleExactAlarm.isGranted;
    }
    return true;
  }

  Future<void> openAndroidNotificationSettings() async {
    await openAppSettings();
  }
}