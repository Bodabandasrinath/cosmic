import 'package:cloud_firestore/cloud_firestore.dart';

class ContactModel {
  final String contactId;
  final String username;
  final String displayName;
  final String profilePhoto;
  final String bio;
  final bool isBlocked;
  final DateTime addedAt;

  ContactModel({
    required this.contactId,
    required this.username,
    required this.displayName,
    this.profilePhoto = '',
    this.bio = '',
    this.isBlocked = false,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'username': username,
      'displayName': displayName,
      'profilePhoto': profilePhoto,
      'bio': bio,
      'isBlocked': isBlocked,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return ContactModel(
      contactId: map['contactId'] ?? documentId ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      profilePhoto: map['profilePhoto'] ?? '',
      bio: map['bio'] ?? '',
      isBlocked: map['isBlocked'] ?? false,
      addedAt: parseDate(map['addedAt']),
    );
  }

  factory ContactModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ContactModel.fromMap(data, documentId: doc.id);
  }
}
