import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType {
  voice,
  video;

  static CallType fromString(String val) {
    return val.toLowerCase() == 'video' ? CallType.video : CallType.voice;
  }

  String toShortString() => toString().split('.').last;
}

enum CallStatus {
  calling,
  ringing,
  accepted,
  connected,
  rejected,
  busy,
  ended,
  missed,
  failed;

  static CallStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'connected':
        return CallStatus.connected;
      case 'rejected':
        return CallStatus.rejected;
      case 'busy':
        return CallStatus.busy;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      case 'failed':
        return CallStatus.failed;
      default:
        return CallStatus.calling;
    }
  }

  String toShortString() => toString().split('.').last;
}

class CallModel {
  final String callId; // Internal technical session identifier only
  final String callerId;
  final String receiverId;
  final String callerName;
  final String callerPhoto;
  final String receiverName;
  final String receiverPhoto;
  final CallType type;
  final CallStatus status;
  final Map<String, dynamic>? sdpOffer;
  final Map<String, dynamic>? sdpAnswer;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.callerName,
    this.callerPhoto = '',
    required this.receiverName,
    this.receiverPhoto = '',
    this.type = CallType.voice,
    this.status = CallStatus.calling,
    this.sdpOffer,
    this.sdpAnswer,
    required this.createdAt,
    this.acceptedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'type': type.toShortString(),
      'status': status.toShortString(),
      'sdpOffer': sdpOffer,
      'sdpAnswer': sdpAnswer,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'durationSeconds': durationSeconds,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return CallModel(
      callId: map['callId'] ?? documentId ?? '',
      callerId: map['callerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      callerName: map['callerName'] ?? 'Cosmic User',
      callerPhoto: map['callerPhoto'] ?? '',
      receiverName: map['receiverName'] ?? 'Cosmic User',
      receiverPhoto: map['receiverPhoto'] ?? '',
      type: CallType.fromString(map['type'] ?? 'voice'),
      status: CallStatus.fromString(map['status'] ?? 'calling'),
      sdpOffer: map['sdpOffer'] as Map<String, dynamic>?,
      sdpAnswer: map['sdpAnswer'] as Map<String, dynamic>?,
      createdAt: parseDate(map['createdAt']),
      acceptedAt: parseNullableDate(map['acceptedAt']),
      endedAt: parseNullableDate(map['endedAt']),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  factory CallModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CallModel.fromMap(data, documentId: doc.id);
  }

  CallModel copyWith({
    String? callId,
    String? callerId,
    String? receiverId,
    String? callerName,
    String? callerPhoto,
    String? receiverName,
    String? receiverPhoto,
    CallType? type,
    CallStatus? status,
    Map<String, dynamic>? sdpOffer,
    Map<String, dynamic>? sdpAnswer,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      receiverName: receiverName ?? this.receiverName,
      receiverPhoto: receiverPhoto ?? this.receiverPhoto,
      type: type ?? this.type,
      status: status ?? this.status,
      sdpOffer: sdpOffer ?? this.sdpOffer,
      sdpAnswer: sdpAnswer ?? this.sdpAnswer,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
