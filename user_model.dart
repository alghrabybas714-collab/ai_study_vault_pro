import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات المستخدم
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final int streak;
  final int totalStudyTime; // بالدقائق
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastStudyDate;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.streak = 0,
    this.totalStudyTime = 0,
    this.isPremium = false,
    this.premiumExpiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastStudyDate,
  });

  /// إنشاء نموذج من بيانات Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'مستخدم',
      streak: data['streak'] ?? 0,
      totalStudyTime: data['totalStudyTime'] ?? 0,
      isPremium: data['isPremium'] ?? false,
      premiumExpiresAt: data['premiumExpiresAt'] != null
          ? (data['premiumExpiresAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastStudyDate: data['lastStudyDate'] != null
          ? (data['lastStudyDate'] as Timestamp).toDate()
          : null,
    );
  }

  /// تحويل النموذج إلى خريطة للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'streak': streak,
      'totalStudyTime': totalStudyTime,
      'isPremium': isPremium,
      'premiumExpiresAt': premiumExpiresAt != null
          ? Timestamp.fromDate(premiumExpiresAt!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastStudyDate': lastStudyDate != null
          ? Timestamp.fromDate(lastStudyDate!)
          : null,
    };
  }

  /// التحقق من صلاحية الاشتراك المميز
  bool get isPremiumValid {
    if (!isPremium) return false;
    if (premiumExpiresAt == null) return true;
    return DateTime.now().isBefore(premiumExpiresAt!);
  }

  /// الحصول على عدد الأيام المتبقية للاشتراك المميز
  int get premiumDaysRemaining {
    if (!isPremiumValid) return 0;
    if (premiumExpiresAt == null) return 999; // غير محدود
    return premiumExpiresAt!.difference(DateTime.now()).inDays;
  }

  /// تحويل وقت الدراسة من دقائق إلى ساعات
  double get totalStudyHours => totalStudyTime / 60;

  /// التحقق من استمرار السلسلة
  bool get isStreakActive {
    if (lastStudyDate == null) return false;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final lastStudyDay = DateTime(
      lastStudyDate!.year,
      lastStudyDate!.month,
      lastStudyDate!.day,
    );
    return lastStudyDay.isAtSameMomentAs(yesterday) ||
        lastStudyDay.isAtSameMomentAs(DateTime(now.year, now.month, now.day));
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, streak: $streak, isPremium: $isPremium)';
  }
}

/// نموذج جلسة الدراسة
class StudySessionModel {
  final String id;
  final String subject;
  final int durationMinutes;
  final int questionsAnswered;
  final int correctAnswers;
  final double accuracy;
  final DateTime timestamp;

  StudySessionModel({
    required this.id,
    required this.subject,
    required this.durationMinutes,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.accuracy,
    required this.timestamp,
  });

  /// إنشاء نموذج من بيانات Firestore
  factory StudySessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudySessionModel(
      id: doc.id,
      subject: data['subject'] ?? '',
      durationMinutes: data['durationMinutes'] ?? 0,
      questionsAnswered: data['questionsAnswered'] ?? 0,
      correctAnswers: data['correctAnswers'] ?? 0,
      accuracy: double.tryParse(data['accuracy']?.toString() ?? '0') ?? 0,
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// تحويل النموذج إلى خريطة للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'subject': subject,
      'durationMinutes': durationMinutes,
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
      'accuracy': accuracy.toStringAsFixed(2),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  @override
  String toString() {
    return 'StudySessionModel(subject: $subject, duration: $durationMinutes, accuracy: $accuracy%)';
  }
}

/// نموذج رسالة المحادثة
class ChatMessageModel {
  final String id;
  final String message;
  final String response;
  final String subject;
  final DateTime timestamp;
  final String model;

  ChatMessageModel({
    required this.id,
    required this.message,
    required this.response,
    required this.subject,
    required this.timestamp,
    this.model = 'gpt-3.5-turbo',
  });

  /// إنشاء نموذج من بيانات Firestore
  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      message: data['message'] ?? '',
      response: data['response'] ?? '',
      subject: data['subject'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      model: data['model'] ?? 'gpt-3.5-turbo',
    );
  }

  /// تحويل النموذج إلى خريطة للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'response': response,
      'subject': subject,
      'timestamp': Timestamp.fromDate(timestamp),
      'model': model,
    };
  }

  @override
  String toString() {
    return 'ChatMessageModel(subject: $subject, message: ${message.substring(0, 30)}...)';
  }
}

/// نموذج خطة الاشتراك
class SubscriptionPlanModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final List<String> features;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.features,
  });

  @override
  String toString() {
    return 'SubscriptionPlanModel(name: $name, price: $price, duration: $durationDays days)';
  }
}
