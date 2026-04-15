import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// خدمة Firestore للعمليات على قاعدة البيانات
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  /// الحصول على بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      return doc.data();
    } catch (e) {
      debugPrint('❌ خطأ في الحصول على بيانات المستخدم: $e');
      return null;
    }
  }

  /// إنشاء أو تحديث بيانات المستخدم
  Future<void> createOrUpdateUser({
    required String email,
    required String displayName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'streak': 0,
        'totalStudyTime': 0,
        'isPremium': false,
        'premiumExpiresAt': null,
      }, SetOptions(merge: true));

      debugPrint('✅ تم إنشاء/تحديث بيانات المستخدم');
    } catch (e) {
      debugPrint('❌ خطأ في إنشاء/تحديث بيانات المستخدم: $e');
      rethrow;
    }
  }

  /// الحصول على السلسلة الحالية
  Future<int> getCurrentStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      return doc.data()?['streak'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ خطأ في الحصول على السلسلة: $e');
      return 0;
    }
  }

  /// زيادة السلسلة
  Future<void> incrementStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      await _firestore.collection('users').doc(user.uid).update({
        'streak': FieldValue.increment(1),
        'lastStudyDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم زيادة السلسلة');
    } catch (e) {
      debugPrint('❌ خطأ في زيادة السلسلة: $e');
      rethrow;
    }
  }

  /// إعادة تعيين السلسلة
  Future<void> resetStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      await _firestore.collection('users').doc(user.uid).update({
        'streak': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم إعادة تعيين السلسلة');
    } catch (e) {
      debugPrint('❌ خطأ في إعادة تعيين السلسلة: $e');
      rethrow;
    }
  }

  /// إضافة وقت الدراسة
  Future<void> addStudyTime(int minutes) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      await _firestore.collection('users').doc(user.uid).update({
        'totalStudyTime': FieldValue.increment(minutes),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم إضافة $minutes دقيقة من وقت الدراسة');
    } catch (e) {
      debugPrint('❌ خطأ في إضافة وقت الدراسة: $e');
      rethrow;
    }
  }

  /// التحقق من الاشتراك المميز
  Future<bool> isPremium() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final isPremium = doc.data()?['isPremium'] as bool? ?? false;
      final premiumExpiresAt = doc.data()?['premiumExpiresAt'] as Timestamp?;

      if (!isPremium) return false;

      // التحقق من انتهاء الاشتراك
      if (premiumExpiresAt != null) {
        final expiryDate = premiumExpiresAt.toDate();
        if (DateTime.now().isAfter(expiryDate)) {
          // الاشتراك انتهى
          await _firestore.collection('users').doc(user.uid).update({
            'isPremium': false,
          });
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من الاشتراك المميز: $e');
      return false;
    }
  }

  /// تفعيل الاشتراك المميز
  Future<void> activatePremium(int daysCount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      final expiryDate = DateTime.now().add(Duration(days: daysCount));

      await _firestore.collection('users').doc(user.uid).update({
        'isPremium': true,
        'premiumExpiresAt': Timestamp.fromDate(expiryDate),
        'premiumActivatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم تفعيل الاشتراك المميز لمدة $daysCount يوم');
    } catch (e) {
      debugPrint('❌ خطأ في تفعيل الاشتراك المميز: $e');
      rethrow;
    }
  }

  /// حفظ سجل الدراسة
  Future<void> saveStudySession({
    required String subject,
    required int durationMinutes,
    required int questionsAnswered,
    required int correctAnswers,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('studySessions')
          .add({
        'subject': subject,
        'durationMinutes': durationMinutes,
        'questionsAnswered': questionsAnswered,
        'correctAnswers': correctAnswers,
        'accuracy': (correctAnswers / questionsAnswered * 100).toStringAsFixed(2),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم حفظ جلسة الدراسة');
    } catch (e) {
      debugPrint('❌ خطأ في حفظ جلسة الدراسة: $e');
      rethrow;
    }
  }

  /// الحصول على سجل الدراسة
  Stream<QuerySnapshot> getStudySessions() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('studySessions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// حفظ المحادثة
  Future<void> saveChatMessage({
    required String message,
    required String response,
    required String subject,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chatHistory')
          .add({
        'message': message,
        'response': response,
        'subject': subject,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم حفظ المحادثة');
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المحادثة: $e');
      // لا نرمي الخطأ هنا
    }
  }

  /// الحصول على سجل المحادثات
  Stream<QuerySnapshot> getChatHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chatHistory')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// حذف حساب المستخدم
  Future<void> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');

      // حذف بيانات Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // حذف حساب Firebase Auth
      await user.delete();

      debugPrint('✅ تم حذف حساب المستخدم');
    } catch (e) {
      debugPrint('❌ خطأ في حذف حساب المستخدم: $e');
      rethrow;
    }
  }
}
