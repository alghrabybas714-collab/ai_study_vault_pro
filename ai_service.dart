import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// خدمة الذكاء الاصطناعي الآمنة
/// تتواصل مع Firebase Cloud Functions للحصول على إجابات من OpenAI
class AIService {
  static final AIService _instance = AIService._internal();
  
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AIService._internal();

  factory AIService() {
    return _instance;
  }

  /// إرسال سؤال إلى الذكاء الاصطناعي والحصول على إجابة
  /// 
  /// Parameters:
  /// - [question]: السؤال المراد إرساله
  /// - [conversationHistory]: سجل المحادثة السابقة (اختياري)
  /// 
  /// Returns:
  /// - الإجابة من الذكاء الاصطناعي
  /// 
  /// Throws:
  /// - [FirebaseFunctionsException] إذا حدث خطأ في الاتصال
  /// - [Exception] إذا كان المستخدم غير مسجل دخول
  Future<String> askAI({
    required String question,
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      // التحقق من تسجيل دخول المستخدم
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      debugPrint('📤 إرسال سؤال: $question');

      // استدعاء Cloud Function
      final callable = _functions.httpsCallable('askAI');
      
      final response = await callable.call<Map<String, dynamic>>({
        'question': question,
        'userId': user.uid,
        'userEmail': user.email,
        'conversationHistory': conversationHistory ?? [],
        'timestamp': DateTime.now().toIso8601String(),
      });

      // معالجة الاستجابة
      final data = response.data as Map<String, dynamic>;
      final answer = data['answer'] as String?;
      
      if (answer == null || answer.isEmpty) {
        throw Exception('لم تحصل على إجابة من الخادم');
      }

      debugPrint('📥 تم استقبال الإجابة: ${answer.substring(0, 50)}...');
      
      return answer;
      
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ خطأ في Firebase Functions: ${e.code}');
      debugPrint('📝 التفاصيل: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ خطأ غير متوقع: $e');
      rethrow;
    }
  }

  /// الحصول على اقتراحات الدراسة من الذكاء الاصطناعي
  Future<List<String>> getStudySuggestions({
    required String subject,
    required String level,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final callable = _functions.httpsCallable('getStudySuggestions');
      
      final response = await callable.call<Map<String, dynamic>>({
        'subject': subject,
        'level': level,
        'userId': user.uid,
      });

      final data = response.data as Map<String, dynamic>;
      final suggestions = List<String>.from(data['suggestions'] as List);
      
      return suggestions;
      
    } catch (e) {
      debugPrint('❌ خطأ في الحصول على الاقتراحات: $e');
      rethrow;
    }
  }

  /// تصحيح الإجابة من قبل الذكاء الاصطناعي
  Future<Map<String, dynamic>> correctAnswer({
    required String question,
    required String userAnswer,
    required String subject,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final callable = _functions.httpsCallable('correctAnswer');
      
      final response = await callable.call<Map<String, dynamic>>({
        'question': question,
        'userAnswer': userAnswer,
        'subject': subject,
        'userId': user.uid,
      });

      final data = response.data as Map<String, dynamic>;
      
      return {
        'isCorrect': data['isCorrect'] as bool,
        'feedback': data['feedback'] as String,
        'correctAnswer': data['correctAnswer'] as String?,
        'explanation': data['explanation'] as String?,
      };
      
    } catch (e) {
      debugPrint('❌ خطأ في تصحيح الإجابة: $e');
      rethrow;
    }
  }

  /// توليد أسئلة اختبار من الذكاء الاصطناعي
  Future<List<Map<String, dynamic>>> generateQuestions({
    required String subject,
    required int count,
    required String difficulty,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final callable = _functions.httpsCallable('generateQuestions');
      
      final response = await callable.call<Map<String, dynamic>>({
        'subject': subject,
        'count': count,
        'difficulty': difficulty,
        'userId': user.uid,
      });

      final data = response.data as Map<String, dynamic>;
      final questions = List<Map<String, dynamic>>.from(
        data['questions'] as List,
      );
      
      return questions;
      
    } catch (e) {
      debugPrint('❌ خطأ في توليد الأسئلة: $e');
      rethrow;
    }
  }

  /// شرح مفهوم معين
  Future<String> explainConcept({
    required String concept,
    required String subject,
    required String level,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final callable = _functions.httpsCallable('explainConcept');
      
      final response = await callable.call<Map<String, dynamic>>({
        'concept': concept,
        'subject': subject,
        'level': level,
        'userId': user.uid,
      });

      final data = response.data as Map<String, dynamic>;
      final explanation = data['explanation'] as String?;
      
      if (explanation == null || explanation.isEmpty) {
        throw Exception('لم يتم الحصول على شرح');
      }
      
      return explanation;
      
    } catch (e) {
      debugPrint('❌ خطأ في شرح المفهوم: $e');
      rethrow;
    }
  }

  /// حفظ المحادثة في Firestore
  Future<void> saveChatMessage({
    required String message,
    required String response,
    required String subject,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final callable = _functions.httpsCallable('saveChatMessage');
      
      await callable.call<Map<String, dynamic>>({
        'message': message,
        'response': response,
        'subject': subject,
        'userId': user.uid,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ تم حفظ المحادثة');
      
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المحادثة: $e');
      // لا نرمي الخطأ هنا لأنه ليس حرجاً
    }
  }
}
