import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class ProductivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user model from Firestore
  Future<UserModel?> getUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) return UserModel.fromFirestore(doc);
    return null;
  }

  // Save a focus session
  Future<void> saveFocusSession(ProductivitySession session) async {
    await _firestore
        .collection('sessions')
        .doc(session.id)
        .set(session.toFirestore());

    // Update user stats
    await _firestore.collection('users').doc(session.userId).update({
      'totalFocusSeconds': FieldValue.increment(session.durationSeconds),
    });
  }

  // Get sessions for a user
  Future<List<ProductivitySession>> getSessions(String userId,
      {int limit = 30}) async {
    final query = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .get();

    final sessions = query.docs.map((d) => ProductivitySession.fromFirestore(d)).toList();
    
    // Sort client-side to avoid requiring composite indices in Firestore
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    return sessions.take(limit).toList();
  }

  // Get today's sessions
  Future<List<ProductivitySession>> getTodaySessions(String userId) async {
    // Fetch all sessions and filter client-side to avoid composite index requirements
    final allSessions = await getSessions(userId, limit: 100);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return allSessions.where((s) {
      final sDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      return sDate.isAtSameMomentAs(today);
    }).toList();
  }

  // Get weekly productivity data (for charts)
  Future<Map<String, dynamic>> getWeeklyData(String userId) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // Fetch and filter client-side to avoid index issues
    final query = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .get();

    final sessionsDocs = query.docs.where((doc) {
      final startTime = (doc.data()['startTime'] as Timestamp).toDate();
      return startTime.isAfter(weekAgo);
    });

    Map<String, int> dailyMinutes = {};
    Map<String, int> dailyScore = {};
    Map<String, int> appUsageTotals = {};

    for (var doc in sessionsDocs) {
      final session = ProductivitySession.fromFirestore(doc);
      final dayKey =
          '${session.startTime.month}/${session.startTime.day}';
      dailyMinutes[dayKey] =
          (dailyMinutes[dayKey] ?? 0) + session.durationSeconds;
      dailyScore[dayKey] =
          ((dailyScore[dayKey] ?? 0) + session.focusScore) ~/ 2;

      session.appUsageMinutes.forEach((app, minutes) {
        appUsageTotals[app] = (appUsageTotals[app] ?? 0) + minutes;
      });
    }

    return {
      'dailyMinutes': dailyMinutes,
      'dailyScore': dailyScore,
      'appUsageTotals': appUsageTotals,
      'totalSessions': sessionsDocs.length,
    };
  }

  // Save AI suggestion
  Future<void> saveAiSuggestion(
      String userId, AiSuggestion suggestion) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('suggestions')
        .doc(suggestion.id)
        .set(suggestion.toFirestore());
  }

  // Get AI suggestions
  Future<List<AiSuggestion>> getAiSuggestions(String userId) async {
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('suggestions')
        .orderBy('generatedAt', descending: true)
        .limit(20)
        .get();

    return query.docs.map((d) => AiSuggestion.fromFirestore(d)).toList();
  }

  // Mark suggestion as read/applied
  Future<void> updateSuggestion(
      String userId, String suggestionId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('suggestions')
        .doc(suggestionId)
        .update(data);
  }

  // Calculate productivity score from sessions
  int calculateProductivityScore(List<ProductivitySession> sessions) {
    if (sessions.isEmpty) return 0;
    final avgScore =
        sessions.map((s) => s.focusScore).reduce((a, b) => a + b) ~/
            sessions.length;
    return avgScore.clamp(0, 100);
  }

  // Update daily streak
  Future<void> updateStreak(String userId) async {
    final userDoc =
        await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data()!;
    final lastActive = data['lastActiveDate'] != null
        ? (data['lastActiveDate'] as Timestamp).toDate()
        : null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int currentStreak = data['streak'] ?? 0;
    int currentScore = data['productivityScore'] ?? 0;

    if (lastActive == null) {
      currentStreak = 1;
    } else {
      final lastDate = DateTime(lastActive.year, lastActive.month, lastActive.day);
      final diff = today.difference(lastDate).inDays;
      if (diff == 1) {
        // Consecutive day — increment
      } else if (diff > 1) {
        // Streak broken — reset
        currentStreak = 1;
      }
      // diff == 0 means same day, streak stays the same
    }

    // Increment productivity score and sessions for starting/completing a session
    currentScore += 10;
    int totalSessions = (data['totalSessions'] ?? 0) + 1;
    int activeDays = data['activeDays'] ?? 0;

    if (lastActive == null || today.difference(DateTime(lastActive.year, lastActive.month, lastActive.day)).inDays >= 1) {
      activeDays++;
    }

    await _firestore.collection('users').doc(userId).update({
      'streak': currentStreak,
      'productivityScore': currentScore,
      'totalSessions': totalSessions,
      'activeDays': activeDays,
      'lastActiveDate': Timestamp.fromDate(now),
    });
  }
}
