import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Helper to generate consistent deterministic 1-on-1 chatId
  String getChatId(String userA, String userB) {
    final list = [userA, userB]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Get or Create a 1-to-1 Conversation
  Future<String> getOrCreateChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    final chatDoc = _firestore.collection(AppConstants.chatsCollection).doc(chatId);

    final snapshot = await chatDoc.get();
    if (!snapshot.exists) {
      await chatDoc.set({
        'id': chatId,
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastMessageType': 'text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'unreadCounts': {
          currentUserId: 0,
          otherUserId: 0,
        },
      });
    }

    return chatId;
  }

  /// Stream user's conversations list
  Stream<List<ChatModel>> streamUserConversations(String currentUserId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatModel.fromDocument(doc)).toList());
  }

  /// Stream messages in a chat (ordered by timestamp descending for reverse ListView)
  Stream<List<MessageModel>> streamMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromDocument(doc)).toList());
  }

  /// Send a message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final messageId = _uuid.v4();
    final now = DateTime.now();

    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      chatId: chatId,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      timestamp: now,
      isSeen: false,
      isDelivered: false,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderName: replyToSenderName,
      reactions: {},
      isDeleted: false,
    );

    // Batch write message and update conversation lastMessage & unread count
    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);

    batch.set(messageRef, message.toMap());

    final chatRef = _firestore.collection(AppConstants.chatsCollection).doc(chatId);

    String lastPreview = text;
    if (type == MessageType.image) lastPreview = '📷 Photo';
    if (type == MessageType.video) lastPreview = '🎥 Video';
    if (type == MessageType.audio) lastPreview = '🎤 Voice message';

    batch.update(chatRef, {
      'lastMessage': lastPreview,
      'lastMessageType': type.toShortString(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Toggle message reaction (Instagram-style ❤️, 😂, 😮, 😢, 👏, 🔥)
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);

    final snapshot = await messageRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

    if (reactions[userId] == emoji) {
      // Remove reaction if already applied
      await messageRef.update({
        'reactions.$userId': FieldValue.delete(),
      });
    } else {
      // Set / update reaction
      await messageRef.update({
        'reactions.$userId': emoji,
      });
    }
  }

  /// Mark all messages in a chat as seen by the current user
  Future<void> markMessagesAsSeen({
    required String chatId,
    required String currentUserId,
  }) async {
    final unreadMessages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isSeen', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'isSeen': true,
        'isDelivered': true,
      });
    }

    final chatRef = _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    batch.update(chatRef, {
      'unreadCounts.$currentUserId': 0,
    });

    await batch.commit();
  }

  /// Mark messages as delivered when receiver is online
  Future<void> markMessagesAsDelivered({
    required String chatId,
    required String currentUserId,
  }) async {
    final undelivered = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isDelivered', isEqualTo: false)
        .get();

    if (undelivered.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in undelivered.docs) {
      batch.update(doc.reference, {'isDelivered': true});
    }
    await batch.commit();
  }

  /// Delete message (supports soft delete for everyone or deletion)
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String currentUserId,
    bool forEveryone = true,
  }) async {
    if (senderId != currentUserId) return; // Users can only delete their own messages

    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);

    if (forEveryone) {
      // Soft-delete so chat history shows "This message was deleted"
      await messageRef.update({
        'text': 'This message was deleted',
        'isDeleted': true,
        'mediaUrl': null,
        'thumbnailUrl': null,
        'type': MessageType.text.toShortString(),
        'reactions': {},
      });
    } else {
      await messageRef.delete();
    }
  }

  /// Filter messages in a chat by search query
  List<MessageModel> filterMessages(List<MessageModel> messages, String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return messages;
    return messages.where((m) => !m.isDeleted && m.text.toLowerCase().contains(clean)).toList();
  }
}
