import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Skip on web platform
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  /// Schedule daily streak reminder at 9:00 AM
  Future<void> scheduleDailyStreakReminder() async {
    if (kIsWeb) return;

    // Cancel existing streak reminders first
    await _notifications.cancel(1001);

    const androidDetails = AndroidNotificationDetails(
      'streak_channel',
      'Streak Reminders',
      channelDescription: 'Daily reminders to maintain your productivity streak',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification immediately as a reminder, then re-schedule daily
    await _notifications.periodicallyShow(
      1001,
      '🔥 Keep your streak alive!',
      'Don\'t forget to log in and complete a focus session today to maintain your streak!',
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Schedule daily login reminder at evening (6 PM check)
  Future<void> scheduleDailyLoginReminder() async {
    if (kIsWeb) return;

    await _notifications.cancel(1002);

    const androidDetails = AndroidNotificationDetails(
      'login_channel',
      'Login Reminders',
      channelDescription: 'Daily reminders to log in and track productivity',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.periodicallyShow(
      1002,
      '📊 Track your productivity!',
      'Open ProductivityAI to log your focus sessions and keep improving!',
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Show an instant notification (e.g., streak at risk)
  Future<void> showStreakAtRiskNotification(int currentStreak) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'streak_alert_channel',
      'Streak Alerts',
      channelDescription: 'Alerts when your streak is at risk',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2001,
      '⚠️ Streak at risk!',
      'Your $currentStreak-day streak will reset if you don\'t complete a session today!',
      details,
    );
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  /// Enable all daily notifications
  Future<void> enableDailyNotifications() async {
    await scheduleDailyStreakReminder();
    await scheduleDailyLoginReminder();
  }
}
