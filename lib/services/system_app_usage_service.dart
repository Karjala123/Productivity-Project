import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_usage/app_usage.dart';

class SystemAppUsageService {
  static Future<List<AppUsageInfo>> getTodayUsage() async {
    List<AppUsageInfo> infoList = [];

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = now;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        List<AppUsageInfo> rawList = await AppUsage().getAppUsage(
          startDate,
          endDate,
        );

        for (var info in rawList) {
          // Filter out distracting system packages
          if (_isSystemApp(info.packageName)) continue;
          if (info.usage.inMinutes < 1) continue;

          String friendlyName = _getFriendlyAppName(
            info.packageName,
            info.appName,
          );

          infoList.add(
            _MockAppUsageInfo(
              friendlyName,
              info.packageName,
              info.usage,
              info.startDate,
              info.endDate,
              info.lastForeground,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error getting Android app usage: $e');
        // If permission is missing, it will throw an error or return empty.
      }
    } else {
      // Return dummy data for Desktop/iOS/Web as native APIs aren't easily exposed
      if (kDebugMode || true) {
        infoList = [
          _MockAppUsageInfo(
            'Visual Studio Code',
            'com.microsoft.vscode',
            const Duration(hours: 3, minutes: 20),
            startDate,
            endDate,
            endDate,
          ),
          _MockAppUsageInfo(
            'Chrome',
            'com.google.chrome',
            const Duration(hours: 2, minutes: 15),
            startDate,
            endDate,
            endDate,
          ),
          _MockAppUsageInfo(
            'Slack',
            'com.slack',
            const Duration(hours: 1, minutes: 30),
            startDate,
            endDate,
            endDate,
          ),
          _MockAppUsageInfo(
            'Spotify',
            'com.spotify',
            const Duration(minutes: 45),
            startDate,
            endDate,
            endDate,
          ),
        ];
      }
    }

    return infoList;
  }

  static bool _isSystemApp(String packageName) {
    final lower = packageName.toLowerCase();
    // Do not filter out primary apps even if they contain typical android package names
    if (lower.contains('youtube') || lower == 'com.android.chrome')
      return false;

    // Filter out standard background/OS processes
    if (lower.startsWith('com.android.system') ||
        lower.startsWith('com.android.providers') ||
        lower.startsWith('com.android.server') ||
        lower.startsWith('com.android.settings') ||
        lower.startsWith('com.sec.android') ||
        lower.contains('systemui') ||
        lower.contains('launcher') ||
        lower.contains('nexuslauncher')) {
      return true;
    }
    return false;
  }

  static String _getFriendlyAppName(String packageName, String defaultName) {
    final lower = packageName.toLowerCase();

    // Most popular packages directly mapped for beautiful UI
    if (lower.contains('youtube')) return 'YouTube';
    if (lower.contains('whatsapp')) return 'WhatsApp';
    if (lower.contains('instagram')) return 'Instagram';
    if (lower.contains('facebook')) return 'Facebook';
    if (lower.contains('chrome')) return 'Chrome';
    if (lower.contains('tiktok')) return 'TikTok';
    if (lower.contains('snapchat')) return 'Snapchat';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('telegram')) return 'Telegram';
    if (lower.contains('discord')) return 'Discord';
    if (lower.contains('reddit')) return 'Reddit';
    if (lower.contains('maps')) return 'Maps';
    if (lower.contains('twitter') ||
        lower == 'com.twitter.android' ||
        lower == 'com.x.x') return 'X (Twitter)';
    if (lower.contains('linkedin')) return 'LinkedIn';

    // Fallback: capitalize the default token parsed by the package
    if (defaultName.isEmpty) return 'Unknown App';
    return defaultName[0].toUpperCase() + defaultName.substring(1);
  }
}

class _MockAppUsageInfo implements AppUsageInfo {
  @override
  final String appName;
  @override
  final String packageName;
  @override
  final Duration usage;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  final DateTime lastForeground;

  _MockAppUsageInfo(
    this.appName,
    this.packageName,
    this.usage,
    this.startDate,
    this.endDate,
    this.lastForeground,
  );
}
