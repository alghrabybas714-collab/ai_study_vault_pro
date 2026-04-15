import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _controller = TextEditingController();
  final _functions = FirebaseFunctions.instance;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<ChatMessage> _chatMessages = [];
  int _streak = 0;
  bool _premium = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _streak = doc.data()?['streak'] ?? 0;
          _premium = doc.data()?['premium'] ?? false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _askAI() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _chatMessages.add(ChatMessage(
        text: input,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
    });

    try {
      final result = await _functions.httpsCallable('askAI').call({
        'input': input,
      });

      setState(() {
        _chatMessages.add(ChatMessage(
          text: result.data as String,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      // Log event
      await _logEvent('chat');
    } catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage(
          text: 'حدث خطأ: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStreak() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();

      int current = doc.data()?['streak'] ?? 0;
      current++;

      await ref.set({'streak': current}, SetOptions(merge: true));

      setState(() {
        _streak = current;
      });

      await _logEvent('streak');
    } catch (e) {
      print('Error updating streak: $e');
    }
  }

  Future<void> _togglePremium() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      _premium = !_premium;

      await _db.collection('users').doc(uid).set(
        {'premium': _premium},
        SetOptions(merge: true),
      );

      setState(() {});

      await _logEvent(_premium ? 'premium_enabled' : 'premium_disabled');
    } catch (e) {
      print('Error toggling premium: $e');
    }
  }

  Future<void> _logEvent(String type) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _db.collection('events').add({
        'uid': uid,
        'type': type,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging event: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Vault Pro'),
        actions: [
          IconButton(
            onPressed: _togglePremium,
            icon: Icon(
              _premium ? Icons.verified : Icons.lock,
              color: Colors.amber,
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔥 السلسلة',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '$_streak',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الحالة',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _premium ? '⭐ PRO' : '📱 FREE',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chat Messages
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.white30,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ابدأ محادثة مع الذكاء الاصطناعي',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message =
                          _chatMessages[_chatMessages.length - 1 - index];
                      return ChatBubble(message: message);
                    },
                  ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'اسأل الذكاء الاصطناعي...',
                          enabled: !_isLoading,
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isLoading ? null : _askAI,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _updateStreak,
                        icon: const Icon(Icons.local_fire_department),
                        label: const Text('زيادة السلسلة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
