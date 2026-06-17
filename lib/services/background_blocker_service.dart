import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class BackgroundBlockerService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'blocker_service',
        initialNotificationTitle: 'Productivity Guard Active',
        initialNotificationContent: 'Monitoring your app limits...',
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Main loop
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (!(await service.isForegroundService())) {
          // Keep it alive
        }
      }

      await checkAppLimits();
    });
  }

  static Future<void> checkAppLimits() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = now;

      // Get real usage
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(
        startDate,
        endDate,
      );
      final prefs = await SharedPreferences.getInstance();

      for (var info in infoList) {
        final double? limitMinutes = prefs.getDouble(
          'limit_${info.packageName}',
        );

        if (limitMinutes != null && info.usage.inMinutes >= limitMinutes) {
          // IMPORTANT: Only block if the app was recently in the foreground (within last 10 seconds)
          // This prevents blocking the phone while using other apps.
          final lastForeground = info.lastForeground;
          final timeSinceForeground = now
              .difference(lastForeground)
              .inSeconds
              .abs();

          if (timeSinceForeground < 15) {
            // Check if we already showed the overlay recently
            final lastShown =
                prefs.getInt('last_shown_${info.packageName}') ?? 0;
            final currentTime = DateTime.now().millisecondsSinceEpoch;

            // Re-show every 2 minutes if they try to go back in
            if (currentTime - lastShown > 2 * 60 * 1000) {
              bool isOverlayOpen = await FlutterOverlayWindow.isActive();
              if (!isOverlayOpen) {
                await FlutterOverlayWindow.showOverlay(
                  height: WindowSize.matchParent,
                  width: WindowSize.matchParent,
                  alignment: OverlayAlignment.center,
                  visibility: NotificationVisibility.visibilityPublic,
                  flag: OverlayFlag.focusPointer,
                  enableDrag: false,
                );
                await prefs.setInt(
                  'last_shown_${info.packageName}',
                  currentTime,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      // Background errors
    }
  }
}
