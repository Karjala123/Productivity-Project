import 'package:dio/dio.dart';
import '../models/user_model.dart';

class AiService {
  final Dio _dio = Dio();

  // Replace with your backend API URL (Node.js/Python relay to Anthropic)
  static const String _baseUrl =
      'https://productivityai-backend.onrender.com/api';

  // Generate AI productivity suggestions
  Future<List<AiSuggestion>> generateSuggestions({
    required UserModel user,
    required Map<String, dynamic> weeklyData,
    required List<ProductivitySession> recentSessions,
  }) async {
    try {
      // Build context for AI
      final context = _buildProductivityContext(
        user,
        weeklyData,
        recentSessions,
      );

      final response = await _dio.post(
        '$_baseUrl/ai/suggestions',
        data: {
          'userId': user.uid,
          'context': context,
          'prompt':
              '''
Analyze this user's productivity data and generate 5 personalized suggestions.
Return a JSON array with objects containing: title, description, category (focus/break/app_usage/schedule), priority (high/medium/low).

User Data:
$context
          ''',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      // Parse suggestions from response
      final List suggestions = response.data['suggestions'] ?? [];
      return suggestions.asMap().entries.map((entry) {
        final s = entry.value;
        return AiSuggestion(
          id: '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
          title: s['title'] ?? 'Productivity Tip',
          description: s['description'] ?? '',
          category: s['category'] ?? 'focus',
          priority: s['priority'] ?? 'medium',
          generatedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      // Return local fallback suggestions if API fails
      return _getFallbackSuggestions(user, weeklyData);
    }
  }

  // AI Chatbot message
  Future<String> sendChatMessage({
    required String message,
    required List<ChatMessage> history,
    required UserModel user,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final conversationHistory = history
          .map(
            (m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            },
          )
          .toList();

      final response = await _dio.post(
        '$_baseUrl/ai/chat',
        data: {
          'message': message,
          'history': conversationHistory,
          'systemContext':
              '''
You are an AI productivity coach for ${user.name}. 
Help them improve their focus, manage digital wellness, and optimize their work habits.
Current productivity score: ${user.productivityScore}/100.
Total focus time today: ${userData['todayMinutes'] ?? 0} minutes.
Current streak: ${user.streak} days.
Be concise, actionable, and motivating.
          ''',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      return response.data['reply'] ??
          'I could not process your message. Please try again.';
    } catch (e) {
      print('AI Service Error: $e');
      // Local Fallback Coach logic when backend is down
      return _generateLocalChatReply(message, user, userData);
    }
  }

  // Generate a context-aware local response for the chatbot
  String _generateLocalChatReply(
    String message,
    UserModel user,
    Map<String, dynamic> userData,
  ) {
    final msg = message.toLowerCase();
    final todayMins = userData['todayMinutes'] ?? 0;

    if (msg.contains('study') || msg.contains('routine')) {
      return "To build a great study routine, I recommend focusing on 'Deep Work' blocks. Since you've done $todayMins minutes today, try adding a 25-minute Pomodoro session next. Would you like me to set a focus timer for you?";
    } else if (msg.contains('focus') || msg.contains('concentrate')) {
      return "Focus is a muscle! You're currently at a ${user.productivityScore}/100 score. To improve this, try minimizing 'context switching' between apps. Which apps are distracting you the most right now?";
    } else if (msg.contains('score')) {
      return "Your current productivity score is ${user.productivityScore}. This is calculated based on your $todayMins minutes of focus time and your ${user.streak}-day streak. You're doing great!";
    } else if (msg.contains('hello') || msg.contains('hi')) {
      return "Hello ${user.name}! I'm here to help you stay productive. You've already logged $todayMins minutes of focus today. What's our goal for the next hour?";
    }

    return "I'm currently in 'offline coaching mode' as I can't reach my primary brain. However, based on your data: you have a ${user.streak}-day streak and $todayMins minutes of focus today. Keep it up!";
  }

  // Predict productivity score
  Future<int> predictProductivityScore({
    required String userId,
    required Map<String, dynamic> currentData,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/ai/predict-score',
        data: {'userId': userId, 'data': currentData},
      );
      return response.data['predictedScore'] ?? 70;
    } catch (e) {
      return _calculateLocalScore(currentData);
    }
  }

  // Build context string from user data
  String _buildProductivityContext(
    UserModel user,
    Map<String, dynamic> weeklyData,
    List<ProductivitySession> sessions,
  ) {
    final appUsage = weeklyData['appUsageTotals'] as Map<String, int>? ?? {};
    final topApps = appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return '''
Name: ${user.name}
Current Score: ${user.productivityScore}/100
Streak: ${user.streak} days
Weekly Focus Minutes: ${weeklyData['dailyMinutes']?.values.fold(0, (a, b) => (a as int) + (b as int)) ?? 0}
Total Sessions This Week: ${weeklyData['totalSessions'] ?? 0}
Top Apps Used: ${topApps.take(5).map((e) => '${e.key}: ${e.value}min').join(', ')}
Average Session Duration: ${sessions.isEmpty ? 0 : sessions.map((s) => s.durationSeconds).reduce((a, b) => a + b) ~/ (sessions.length * 60)} minutes
    ''';
  }

  // Local fallback suggestions
  List<AiSuggestion> _getFallbackSuggestions(
    UserModel user,
    Map<String, dynamic> weeklyData,
  ) {
    return [
      AiSuggestion(
        id: 'fallback_1',
        title: 'Try the Pomodoro Technique',
        description:
            'Work for 25 minutes, then take a 5-minute break. This pattern has been shown to boost focus and reduce mental fatigue significantly.',
        category: 'focus',
        priority: 'high',
        generatedAt: DateTime.now(),
      ),
      AiSuggestion(
        id: 'fallback_2',
        title: 'Schedule Your Deep Work',
        description:
            'Block 2–3 hours in the morning for your most important tasks when your cognitive performance is at its peak.',
        category: 'schedule',
        priority: 'high',
        generatedAt: DateTime.now(),
      ),
      AiSuggestion(
        id: 'fallback_3',
        title: 'Reduce Social Media Usage',
        description:
            'Limit social media to 30 minutes per day. Consider using app timers to enforce this boundary automatically.',
        category: 'app_usage',
        priority: 'medium',
        generatedAt: DateTime.now(),
      ),
      AiSuggestion(
        id: 'fallback_4',
        title: 'Take Regular Movement Breaks',
        description:
            'Every 90 minutes, step away from your screen for at least 5 minutes. A short walk dramatically improves focus quality.',
        category: 'break',
        priority: 'medium',
        generatedAt: DateTime.now(),
      ),
      AiSuggestion(
        id: 'fallback_5',
        title: 'Maintain Your ${user.streak}-Day Streak',
        description:
            'You\'re on a ${user.streak}-day productivity streak! Keep going — consistency is the foundation of lasting high performance.',
        category: 'focus',
        priority: 'low',
        generatedAt: DateTime.now(),
      ),
    ];
  }

  // Local score calculation fallback
  int _calculateLocalScore(Map<String, dynamic> data) {
    int score = 50;
    final focusMinutes = data['focusMinutes'] ?? 0;
    final breaksTaken = data['breaksTaken'] ?? 0;
    final distractions = data['distractions'] ?? 0;

    if (focusMinutes > 120)
      score += 20;
    else if (focusMinutes > 60)
      score += 10;

    if (breaksTaken >= 2 && breaksTaken <= 5) score += 15;

    if (distractions < 3)
      score += 15;
    else if (distractions > 10)
      score -= 10;

    return score.clamp(0, 100);
  }
}
