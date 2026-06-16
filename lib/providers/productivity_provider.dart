import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/productivity_service.dart';
import '../services/system_app_usage_service.dart';
import 'package:app_usage/app_usage.dart';



class ProductivityProvider extends ChangeNotifier {
  final ProductivityService _productivityService = ProductivityService();

  List<ProductivitySession> _recentSessions = [];
  List<ProductivitySession> _todaySessions = [];
  Map<String, dynamic> _weeklyData = {};
  List<AiSuggestion> _suggestions = [];
  List<AppUsageInfo> _systemAppUsage = [];
  int _todayFocusMinutes = 0;
  int _currentScore = 0;
  bool _isLoading = false;

  List<ProductivitySession> get recentSessions => _recentSessions;
  List<ProductivitySession> get todaySessions => _todaySessions;
  Map<String, dynamic> get weeklyData => _weeklyData;
  List<AiSuggestion> get suggestions => _suggestions;
  List<AppUsageInfo> get systemAppUsage => _systemAppUsage;
  int get todayFocusMinutes => _todayFocusMinutes;
  int get currentScore => _currentScore;
  bool get isLoading => _isLoading;

  Future<void> loadData(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _productivityService.getSessions(userId, limit: 30),
        _productivityService.getWeeklyData(userId),
        _productivityService.getTodaySessions(userId),
        _productivityService.getUserModel(userId),
        SystemAppUsageService.getTodayUsage(),
        // We'll fetch suggestions separately to handle mapping
      ]);

      _recentSessions = results[0] as List<ProductivitySession>;
      _weeklyData = results[1] as Map<String, dynamic>;
      _todaySessions = results[2] as List<ProductivitySession>;
      final userModel = results[3] as UserModel?;
      _systemAppUsage = results[4] as List<AppUsageInfo>;
      
      if (userModel != null) {
        _currentScore = userModel.productivityScore;
      }

      _todayFocusMinutes = _todaySessions.fold(
          0, (sum, session) => sum + (session.durationSeconds ~/ 60));

      // Fetch actual suggestions
      await refreshSuggestionsFromDb(userId);

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading productivity data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSuggestionsFromDb(String userId) async {
    final rawSuggestions = await _productivityService.getAiSuggestions(userId);
    
    if (rawSuggestions.isEmpty) {
      _suggestions = [
        AiSuggestion(
          id: 'sug_0',
          title: 'Try the Pomodoro Technique',
          description: 'Based on your recent activity, we recommend focus techniques.',
          category: 'focus',
          priority: 'medium',
          generatedAt: DateTime.now(),
        ),
        AiSuggestion(
          id: 'sug_1',
          title: 'Reduce Social Media Usage',
          description: 'Based on your recent activity, we recommend focus techniques.',
          category: 'app_usage',
          priority: 'medium',
          generatedAt: DateTime.now(),
        ),
      ];
    } else {
      _suggestions = rawSuggestions;
    }
  }

  Future<UserModel?> startFocusMode(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Logic for starting a focus session (e.g., updating user status if needed)
      return await _productivityService.getUserModel(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> endFocusMode(UserModel user, {
    int durationSeconds = 0,
    int focusScore = 80,
    Map<String, int> appUsage = const {},
  }) async {
    final session = ProductivitySession(
      id: '',
      userId: user.uid,
      startTime: DateTime.now().subtract(Duration(seconds: durationSeconds)),
      endTime: DateTime.now(),
      durationSeconds: durationSeconds,
      focusScore: focusScore,
      sessionType: 'focus',
      appsUsed: appUsage.keys.toList(),
      appUsageMinutes: appUsage,
    );

    try {
      await _productivityService.saveFocusSession(session);
      await _productivityService.updateStreak(user.uid);

      // Re-read the updated user data
      final updatedUser = await _productivityService.getUserModel(user.uid);
      if (updatedUser != null) {
        _currentScore = updatedUser.productivityScore;
      }

      await loadData(user.uid);
      return updatedUser;
    } catch (e) {
      debugPrint('Error saving session: $e');
      return null;
    }
  }

  Future<void> refreshSuggestions(UserModel user, Map<String, dynamic> weeklyData) async {
    _isLoading = true;
    notifyListeners();
    try {
      await refreshSuggestionsFromDb(user.uid);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markSuggestionRead(String userId, String suggestionId) async {
    // Update local state
    final index = _suggestions.indexWhere((s) => s.id == suggestionId);
    if (index != -1) {
      final s = _suggestions[index];
      _suggestions[index] = AiSuggestion(
        id: s.id,
        title: s.title,
        description: s.description,
        category: s.category,
        priority: s.priority,
        generatedAt: s.generatedAt,
        isRead: true,
        isApplied: true,
      );
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> getThisWeekChartData() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    final List<Map<String, dynamic>> chartData = [];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dayKey = '${date.month}/${date.day}';
      final dayLabel = _getDayLabel(date.weekday);

      final seconds = _weeklyData['dailyMinutes']?[dayKey] ?? 0;
      final score = _weeklyData['dailyScore']?[dayKey] ?? 0;
      
      chartData.add({
        'day': dayLabel,
        'date': dayKey,
        'seconds': seconds,
        'score': score,
        'isToday': date.year == now.year && date.month == now.month && date.day == now.day,
      });
    }

    return chartData;
  }

  String _getDayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  String getPeakHours() {
    if (_recentSessions.isEmpty) return 'No data yet';

    final Map<int, int> hourCounts = {};
    for (var session in _recentSessions) {
      final hour = session.startTime.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    if (hourCounts.isEmpty) return 'No data yet';

    int peakStartHour = 0;
    int maxCount = 0;

    for (int i = 0; i < 24; i++) {
      final count = (hourCounts[i] ?? 0) + (hourCounts[(i + 1) % 24] ?? 0);
      if (count > maxCount) {
        maxCount = count;
        peakStartHour = i;
      }
    }

    final endHour = (peakStartHour + 2) % 24;
    final startStr = _formatHour(peakStartHour);
    final endStr = _formatHour(endHour);

    return '$startStr–$endStr';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }
}
