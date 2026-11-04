import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  video,
  audio;

  static MessageType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      default:
        return MessageType.text;
    }
  }

  String toShortString() => toString().split('.').last;
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String chatId;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final DateTime timestamp;
  final bool isSeen;
  final bool isDelivered;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderName;
  final Map<String, String> reactions; // userId -> emoji (e.g. {'uid1': '❤️', 'uid2': '😂'})
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.chatId,
    this.type = MessageType.text,
    required this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.timestamp,
    this.isSeen = false,
    this.isDelivered = false,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderName,
    this.reactions = const {},
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'chatId': chatId,
      'type': type.toShortString(),
      'text': text,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'timestamp': Timestamp.fromDate(timestamp),
      'isSeen': isSeen,
      'isDelivered': isDelivered,
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
      'replyToSenderName': replyToSenderName,
      'reactions': reactions,
      'isDeleted': isDeleted,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    // Parse reactions map safely
    final rawReactions = map['reactions'];
    final reactionsMap = <String, String>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (key != null && value != null) {
          reactionsMap[key.toString()] = value.toString();
        }
      });
    }

    return MessageModel(
      id: map['id'] ?? documentId ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      chatId: map['chatId'] ?? '',
      type: MessageType.fromString(map['type'] ?? 'text'),
      text: map['text'] ?? '',
      mediaUrl: map['mediaUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      durationSeconds: map['durationSeconds'],
      timestamp: parseDate(map['timestamp']),
      isSeen: map['isSeen'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToText: map['replyToText'],
      replyToSenderName: map['replyToSenderName'],
      reactions: reactionsMap,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel.fromMap(data, documentId: doc.id);
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? chatId,
    MessageType? type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    DateTime? timestamp,
    bool? isSeen,
    bool? isDelivered,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderName,
    Map<String, String>? reactions,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      timestamp: timestamp ?? this.timestamp,
      isSeen: isSeen ?? this.isSeen,
      isDelivered: isDelivered ?? this.isDelivered,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
