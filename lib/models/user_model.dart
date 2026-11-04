import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String displayName;
  final String username;
  final String email;
  final String phone;
  final String photoURL;
  final String profilePhoto;
  final String bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authProvider;
  final String? fcmToken;

  UserModel({
    required this.uid,
    String? name,
    required this.displayName,
    required this.username,
    required this.email,
    this.phone = '',
    String? photoURL,
    this.profilePhoto = '',
    this.bio = 'Hello! I am using Cosmic ✨',
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    DateTime? updatedAt,
    this.authProvider = 'password',
    this.fcmToken,
  })  : name = (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : (displayName.trim().isNotEmpty ? displayName.trim() : 'Cosmic User'),
        photoURL = (photoURL != null && photoURL.isNotEmpty)
            ? photoURL
            : profilePhoto,
        updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name.trim(),
      'displayName': (displayName.isNotEmpty ? displayName : name).trim(),
      'username': username.toLowerCase().trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'photoURL': photoURL,
      'profilePhoto': profilePhoto.isNotEmpty ? profilePhoto : photoURL,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : FieldValue.serverTimestamp(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'authProvider': authProvider,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final resolvedUid = map['uid']?.toString() ?? documentId ?? '';
    final resolvedName = map['name']?.toString() ?? map['displayName']?.toString() ?? '';
    final resolvedDisplayName = map['displayName']?.toString() ??
        map['name']?.toString() ??
        (resolvedName.isNotEmpty ? resolvedName : 'Cosmic User');
    final resolvedPhoto = map['photoURL']?.toString() ?? map['profilePhoto']?.toString() ?? '';
    final resolvedEmail = map['email']?.toString() ?? '';

    // Derive a clean fallback username if missing
    String defaultUsername;
    if (resolvedEmail.isNotEmpty) {
      defaultUsername = resolvedEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_.]'), '_');
    } else if (resolvedDisplayName.isNotEmpty && resolvedDisplayName != 'Cosmic User') {
      defaultUsername = resolvedDisplayName.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_.]'), '');
    } else {
      defaultUsername = resolvedUid.isNotEmpty && resolvedUid.length >= 6
          ? 'user_${resolvedUid.substring(0, 6)}'
          : 'cosmic_user';
    }

    final rawUsername = map['username']?.toString() ?? '';
    final effectiveUsername = rawUsername.isNotEmpty ? rawUsername : defaultUsername;

    final created = parseDate(map['createdAt']) ?? DateTime.now();
    final updated = parseDate(map['updatedAt']) ?? created;

    return UserModel(
      uid: resolvedUid,
      name: resolvedName.isNotEmpty ? resolvedName : resolvedDisplayName,
      displayName: resolvedDisplayName,
      username: effectiveUsername.toLowerCase().trim(),
      email: resolvedEmail.trim().toLowerCase(),
      phone: map['phone']?.toString() ?? '',
      photoURL: resolvedPhoto,
      profilePhoto: resolvedPhoto,
      bio: map['bio']?.toString() ?? 'Hello! I am using Cosmic ✨',
      isOnline: map['isOnline'] == true,
      lastSeen: parseDate(map['lastSeen']),
      createdAt: created,
      updatedAt: updated,
      authProvider: map['authProvider']?.toString() ?? 'password',
      fcmToken: map['fcmToken']?.toString(),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, documentId: doc.id);
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? displayName,
    String? username,
    String? email,
    String? phone,
    String? photoURL,
    String? profilePhoto,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authProvider,
    String? fcmToken,
  }) {
    final newDisplayName = displayName ?? this.displayName;
    final newName = name ?? this.name;
    final newPhoto = photoURL ?? profilePhoto ?? this.photoURL;

    return UserModel(
      uid: uid ?? this.uid,
      name: newName,
      displayName: newDisplayName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoURL: newPhoto,
      profilePhoto: newPhoto,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authProvider: authProvider ?? this.authProvider,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
