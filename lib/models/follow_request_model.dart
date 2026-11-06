import 'package:cloud_firestore/cloud_firestore.dart';

enum FollowRequestStatus {
  pending,
  accepted,
  rejected;

  String toShortString() => toString().split('.').last;

  static FollowRequestStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return FollowRequestStatus.accepted;
      case 'rejected':
        return FollowRequestStatus.rejected;
      case 'pending':
      default:
        return FollowRequestStatus.pending;
    }
  }
}

class FollowRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final FollowRequestStatus status;
  final String senderUsername;
  final String senderDisplayName;
  final String senderPhotoUrl;
  final String receiverUsername;
  final String receiverDisplayName;
  final String receiverPhotoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FollowRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.senderUsername,
    required this.senderDisplayName,
    this.senderPhotoUrl = '',
    required this.receiverUsername,
    required this.receiverDisplayName,
    this.receiverPhotoUrl = '',
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.toShortString(),
      'senderUsername': senderUsername,
      'senderDisplayName': senderDisplayName,
      'senderPhotoUrl': senderPhotoUrl,
      'receiverUsername': receiverUsername,
      'receiverDisplayName': receiverDisplayName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory FollowRequestModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return FollowRequestModel(
      id: map['id'] ?? documentId ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: FollowRequestStatus.fromString(map['status']),
      senderUsername: map['senderUsername'] ?? '',
      senderDisplayName: map['senderDisplayName'] ?? '',
      senderPhotoUrl: map['senderPhotoUrl'] ?? '',
      receiverUsername: map['receiverUsername'] ?? '',
      receiverDisplayName: map['receiverDisplayName'] ?? '',
      receiverPhotoUrl: map['receiverPhotoUrl'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  factory FollowRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FollowRequestModel.fromMap(data, documentId: doc.id);
  }

  FollowRequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    FollowRequestStatus? status,
    String? senderUsername,
    String? senderDisplayName,
    String? senderPhotoUrl,
    String? receiverUsername,
    String? receiverDisplayName,
    String? receiverPhotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowRequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      senderUsername: senderUsername ?? this.senderUsername,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      receiverDisplayName: receiverDisplayName ?? this.receiverDisplayName,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

