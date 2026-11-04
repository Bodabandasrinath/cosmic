import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _typingTimer;

  /// Update online presence
  Future<void> setOnlineStatus(String userId, bool isOnline) async {
    if (userId.isEmpty) return;
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignored during network switch
    }
  }

  /// Listen to another user's online and lastSeen status
  Stream<Map<String, dynamic>> getUserPresence(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return {'isOnline': false, 'lastSeen': null};
      final data = snapshot.data() ?? {};
      return {
        'isOnline': data['isOnline'] ?? false,
        'lastSeen': (data['lastSeen'] as Timestamp?)?.toDate(),
      };
    });
  }

  /// Set typing status with auto-reset timer to avoid excessive writes
  Future<void> sendTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    if (chatId.isEmpty || userId.isEmpty) return;

    try {
      final typingRef = _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.typingSubcollection)
          .doc(userId);

      if (isTyping) {
        await typingRef.set({
          'isTyping': true,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Cancel previous timer
        _typingTimer?.cancel();
        // Automatically stop typing after 3 seconds of inactivity
        _typingTimer = Timer(const Duration(seconds: 3), () {
          typingRef.set({'isTyping': false});
        });
      } else {
        _typingTimer?.cancel();
        await typingRef.set({'isTyping': false});
      }
    } catch (_) {}
  }

  /// Listen to whether the other user in a chat is typing
  Stream<bool> getTypingStream({required String chatId, required String otherUserId}) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.typingSubcollection)
        .doc(otherUserId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() ?? {};
      return data['isTyping'] == true;
    });
  }

  void dispose() {
    _typingTimer?.cancel();
  }
}
