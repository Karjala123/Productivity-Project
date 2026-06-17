import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final int productivityScore;
  final int totalFocusSeconds;
  final int streak;
  final int totalSessions;
  final int activeDays;
  final DateTime createdAt;
  final Map<String, dynamic> settings;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.productivityScore = 0,
    this.totalFocusSeconds = 0,
    this.streak = 0,
    this.totalSessions = 0,
    this.activeDays = 0,
    required this.createdAt,
    this.settings = const {},
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      productivityScore: data['productivityScore'] ?? 0,
      totalFocusSeconds: data['totalFocusSeconds'] ?? 0,
      streak: data['streak'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      activeDays: data['activeDays'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      settings: data['settings'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'productivityScore': productivityScore,
      'totalFocusSeconds': totalFocusSeconds,
      'streak': streak,
      'totalSessions': totalSessions,
      'activeDays': activeDays,
      'createdAt': Timestamp.fromDate(createdAt),
      'settings': settings,
    };
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    int? productivityScore,
    int? totalFocusSeconds,
    int? streak,
    int? totalSessions,
    int? activeDays,
    Map<String, dynamic>? settings,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      productivityScore: productivityScore ?? this.productivityScore,
      totalFocusSeconds: totalFocusSeconds ?? this.totalFocusSeconds,
      streak: streak ?? this.streak,
      totalSessions: totalSessions ?? this.totalSessions,
      activeDays: activeDays ?? this.activeDays,
      createdAt: createdAt,
      settings: settings ?? this.settings,
    );
  }
}

class ProductivitySession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int focusScore;
  final String sessionType; // 'focus', 'break', 'deep_work'
  final List<String> appsUsed;
  final Map<String, int> appUsageMinutes;

  ProductivitySession({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.focusScore,
    required this.sessionType,
    required this.appsUsed,
    required this.appUsageMinutes,
  });

  factory ProductivitySession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductivitySession(
      id: doc.id,
      userId: data['userId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      durationSeconds: data['durationSeconds'] ?? 0,
      focusScore: data['focusScore'] ?? 0,
      sessionType: data['sessionType'] ?? 'focus',
      appsUsed: List<String>.from(data['appsUsed'] ?? []),
      appUsageMinutes: (data['appUsageMinutes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'focusScore': focusScore,
      'sessionType': sessionType,
      'appsUsed': appsUsed,
      'appUsageMinutes': appUsageMinutes,
    };
  }
}

class AiSuggestion {
  final String id;
  final String title;
  final String description;
  final String category; // 'focus', 'break', 'app_usage', 'schedule'
  final String priority; // 'high', 'medium', 'low'
  final DateTime generatedAt;
  bool isRead;
  bool isApplied;

  AiSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.generatedAt,
    this.isRead = false,
    this.isApplied = false,
  });

  factory AiSuggestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AiSuggestion(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'focus',
      priority: data['priority'] ?? 'medium',
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      isApplied: data['isApplied'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'isRead': isRead,
      'isApplied': isApplied,
    };
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}
