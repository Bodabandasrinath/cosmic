import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';
import 'user_model.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final MessageType lastMessageType;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, int> unreadCounts;
  
  // Non-persisted UI helpers
  final UserModel? otherUser;
  final bool isOtherUserTyping;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    this.lastMessageType = MessageType.text,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.unreadCounts = const {},
    this.otherUser,
    this.isOtherUserTyping = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType.toShortString(),
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastSenderId': lastSenderId,
      'unreadCounts': unreadCounts,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawCounts = map['unreadCounts'] as Map<String, dynamic>? ?? {};
    final parsedCounts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

    return ChatModel(
      id: map['id'] ?? documentId ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageType: MessageType.fromString(map['lastMessageType'] ?? 'text'),
      lastMessageTime: parseDate(map['lastMessageTime']),
      lastSenderId: map['lastSenderId'] ?? '',
      unreadCounts: parsedCounts,
    );
  }

  factory ChatModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatModel.fromMap(data, documentId: doc.id);
  }

  ChatModel copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    MessageType? lastMessageType,
    DateTime? lastMessageTime,
    String? lastSenderId,
    Map<String, int>? unreadCounts,
    UserModel? otherUser,
    bool? isOtherUserTyping,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      otherUser: otherUser ?? this.otherUser,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
    );
  }
}
