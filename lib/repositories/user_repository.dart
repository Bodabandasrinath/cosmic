import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';

/// Centralized Firestore User Profile Service & Repository
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Canonical collection reference
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection(AppConstants.usersCollection);

  /// 1. Create User Profile
  /// Uses users/{uid} as canonical path with server timestamps and all required fields.
  Future<UserModel> createUserProfile({
    required String uid,
    required String name,
    required String email,
    String phone = '',
    String photoURL = '',
    String bio = 'Hello! I am using Cosmic ✨',
    String authProvider = 'password',
    String? username,
    String? fcmToken,
  }) async {
    try {
      final docRef = _usersCol.doc(uid);
      final existingDoc = await docRef.get();

      // Avoid overwriting if profile already exists
      if (existingDoc.exists && existingDoc.data() != null) {
        return UserModel.fromDocument(existingDoc);
      }

      final trimmedName = name.trim();
      final effectiveUsername = (username != null && username.trim().isNotEmpty)
          ? username.trim().toLowerCase()
          : (email.isNotEmpty
              ? email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_.]'), '_').toLowerCase()
              : trimmedName.toLowerCase().replaceAll(' ', '_'));

      final profileMap = <String, dynamic>{
        'uid': uid,
        'name': trimmedName,
        'displayName': trimmedName,
        'username': effectiveUsername,
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'photoURL': photoURL,
        'profilePhoto': photoURL,
        'bio': bio,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'authProvider': authProvider,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      };

      await docRef.set(profileMap);

      return UserModel(
        uid: uid,
        name: trimmedName,
        displayName: trimmedName,
        username: effectiveUsername,
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        photoURL: photoURL,
        profilePhoto: photoURL,
        bio: bio,
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        authProvider: authProvider,
        fcmToken: fcmToken,
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) print('createUserProfile FirebaseException: ${e.code} - ${e.message}');
      throw DatabaseException('Failed to create user profile: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('createUserProfile Error: $e');
      throw DatabaseException('Failed to create user profile: $e');
    }
  }

  /// 2. Get User Profile by UID
  Future<UserModel?> getUserProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    try {
      final doc = await _usersCol.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } on FirebaseException catch (e) {
      if (kDebugMode) print('getUserProfile error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      if (kDebugMode) print('getUserProfile error: $e');
      return null;
    }
  }

  /// Backward-compatible alias
  Future<UserModel?> getUserById(String userId) => getUserProfile(userId);

  /// 3. Update User Profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? displayName,
    String? bio,
    String? phone,
    String? photoURL,
    String? profilePhoto,
    bool? isOnline,
    String? fcmToken,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final resolvedName = name ?? displayName;
      if (resolvedName != null) {
        updates['name'] = resolvedName.trim();
        updates['displayName'] = resolvedName.trim();
      }

      if (bio != null) updates['bio'] = bio.trim();
      if (phone != null) updates['phone'] = phone.trim();

      final resolvedPhoto = photoURL ?? profilePhoto;
      if (resolvedPhoto != null) {
        updates['photoURL'] = resolvedPhoto;
        updates['profilePhoto'] = resolvedPhoto;
      }

      if (isOnline != null) {
        updates['isOnline'] = isOnline;
        if (!isOnline) {
          updates['lastSeen'] = FieldValue.serverTimestamp();
        }
      }

      if (fcmToken != null) {
        updates['fcmToken'] = fcmToken;
      }

      await _usersCol.doc(uid).update(updates);
    } on FirebaseException catch (e) {
      if (kDebugMode) print('updateUserProfile error: ${e.code} - ${e.message}');
      throw DatabaseException('Failed to update profile: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('updateUserProfile error: $e');
      throw DatabaseException('Failed to update profile: $e');
    }
  }

  /// Backward-compatible alias
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? phone,
    String? profilePhoto,
  }) =>
      updateUserProfile(
        uid: userId,
        displayName: displayName,
        bio: bio,
        phone: phone,
        profilePhoto: profilePhoto,
      );

  /// 4. Ensure User Profile
  /// Safely loads or auto-recovers user profile from authenticated Firebase User.
  /// Prevents "User profile not found in Cosmic database" error.
  Future<UserModel> ensureUserProfile(
    User firebaseUser, {
    String? defaultName,
    String? defaultPhone,
    String? defaultUsername,
  }) async {
    try {
      final docRef = _usersCol.doc(firebaseUser.uid);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final existingProfile = UserModel.fromDocument(doc);

        // Check if any critical missing field needs to be merged without overwriting
        final missingUpdates = <String, dynamic>{};
        if (doc.data()?['authProvider'] == null) {
          missingUpdates['authProvider'] = firebaseUser.phoneNumber?.isNotEmpty == true
              ? 'phone'
              : (firebaseUser.providerData.isNotEmpty
                  ? firebaseUser.providerData.first.providerId
                  : 'password');
        }
        if (doc.data()?['name'] == null && existingProfile.displayName.isNotEmpty) {
          missingUpdates['name'] = existingProfile.displayName;
        }
        if (doc.data()?['photoURL'] == null && existingProfile.profilePhoto.isNotEmpty) {
          missingUpdates['photoURL'] = existingProfile.profilePhoto;
        }
        if (doc.data()?['updatedAt'] == null) {
          missingUpdates['updatedAt'] = FieldValue.serverTimestamp();
        }

        if (missingUpdates.isNotEmpty) {
          await docRef.set(missingUpdates, SetOptions(merge: true));
        }

        return existingProfile;
      }

      // Profile does not exist in Firestore -> Auto-recover safely from Firebase Auth
      final resolvedName = firebaseUser.displayName?.trim().isNotEmpty == true
          ? firebaseUser.displayName!.trim()
          : (defaultName?.trim().isNotEmpty == true
              ? defaultName!.trim()
              : (firebaseUser.email?.isNotEmpty == true
                  ? firebaseUser.email!.split('@').first
                  : 'Cosmic User'));

      final resolvedEmail = firebaseUser.email ?? '';
      final resolvedPhone = firebaseUser.phoneNumber ?? defaultPhone ?? '';
      final resolvedPhoto = firebaseUser.photoURL ?? '';
      final authProvider = firebaseUser.phoneNumber?.isNotEmpty == true
          ? 'phone'
          : (firebaseUser.providerData.isNotEmpty
              ? firebaseUser.providerData.first.providerId
              : 'password');

      return await createUserProfile(
        uid: firebaseUser.uid,
        name: resolvedName,
        email: resolvedEmail,
        phone: resolvedPhone,
        photoURL: resolvedPhoto,
        username: defaultUsername,
        authProvider: authProvider,
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) print('ensureUserProfile FirebaseException: ${e.code} - ${e.message}');
      throw DatabaseException('Failed to synchronize user profile: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('ensureUserProfile Error: $e');
      throw DatabaseException('Failed to synchronize user profile: $e');
    }
  }

  /// 5. Delete User Profile
  Future<void> deleteUserProfile(String uid) async {
    try {
      await _usersCol.doc(uid).delete();
    } on FirebaseException catch (e) {
      if (kDebugMode) print('deleteUserProfile error: ${e.code} - ${e.message}');
      throw DatabaseException('Failed to delete profile: ${e.message ?? e.code}');
    }
  }

  /// Search users across Cosmic by username, displayName, or email
  Future<List<UserModel>> searchUsers(String query, {required String currentUserId}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    try {
      final Map<String, UserModel> userMap = {};

      // 1. Search by username prefix
      final usernameSnap = await _usersCol
          .where('username', isGreaterThanOrEqualTo: cleanQuery)
          .where('username', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(20)
          .get();

      for (final doc in usernameSnap.docs) {
        if (doc.id != currentUserId) {
          userMap[doc.id] = UserModel.fromDocument(doc);
        }
      }

      // 2. Search by email prefix
      final emailSnap = await _usersCol
          .where('email', isGreaterThanOrEqualTo: cleanQuery)
          .where('email', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(20)
          .get();

      for (final doc in emailSnap.docs) {
        if (doc.id != currentUserId) {
          userMap[doc.id] = UserModel.fromDocument(doc);
        }
      }

      // 3. Fallback / client-side match against recent users if few results
      if (userMap.length < 5) {
        final recentUsersSnap = await _usersCol.limit(30).get();
        for (final doc in recentUsersSnap.docs) {
          if (doc.id == currentUserId) continue;
          final user = UserModel.fromDocument(doc);
          if (user.displayName.toLowerCase().contains(cleanQuery) ||
              user.name.toLowerCase().contains(cleanQuery) ||
              user.username.toLowerCase().contains(cleanQuery) ||
              user.email.toLowerCase().contains(cleanQuery)) {
            userMap[user.uid] = user;
          }
        }
      }

      return userMap.values.toList();
    } catch (e) {
      if (kDebugMode) print('searchUsers error: $e');
      return [];
    }
  }

  /// Report User
  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      final docRef = _firestore.collection(AppConstants.reportsCollection).doc();
      await docRef.set({
        'reportId': docRef.id,
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (kDebugMode) print('reportUser error: ${e.code} - ${e.message}');
      throw DatabaseException('Failed to submit report: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('reportUser error: $e');
      throw DatabaseException('Failed to submit report: $e');
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked({required String currentUserId, required String targetUserId}) async {
    try {
      final doc = await _usersCol
          .doc(currentUserId)
          .collection(AppConstants.blockedSubcollection)
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Stream User profile by ID
  Stream<UserModel?> streamUser(String userId) {
    return _usersCol.doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Add Contact
  Future<void> addContact({required String currentUserId, required UserModel contactUser}) async {
    final contact = ContactModel(
      contactId: contactUser.uid,
      username: contactUser.username,
      displayName: contactUser.displayName,
      profilePhoto: contactUser.profilePhoto,
      bio: contactUser.bio,
      isBlocked: false,
      addedAt: DateTime.now(),
    );

    await _usersCol
        .doc(currentUserId)
        .collection(AppConstants.contactsSubcollection)
        .doc(contactUser.uid)
        .set(contact.toMap());
  }

  /// Remove Contact
  Future<void> removeContact({required String currentUserId, required String contactId}) async {
    await _usersCol
        .doc(currentUserId)
        .collection(AppConstants.contactsSubcollection)
        .doc(contactId)
        .delete();
  }

  /// Stream Contacts
  Stream<List<ContactModel>> streamContacts(String currentUserId) {
    return _usersCol
        .doc(currentUserId)
        .collection(AppConstants.contactsSubcollection)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ContactModel.fromDocument(doc)).toList());
  }

  /// Block User
  Future<void> blockUser({required String currentUserId, required UserModel targetUser}) async {
    await _usersCol
        .doc(currentUserId)
        .collection(AppConstants.blockedSubcollection)
        .doc(targetUser.uid)
        .set({
      'blockedId': targetUser.uid,
      'username': targetUser.username,
      'displayName': targetUser.displayName,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unblock User
  Future<void> unblockUser({required String currentUserId, required String targetUserId}) async {
    await _usersCol
        .doc(currentUserId)
        .collection(AppConstants.blockedSubcollection)
        .doc(targetUserId)
        .delete();
  }

  /// Stream Blocked Users
  Stream<List<Map<String, dynamic>>> streamBlockedUsers(String currentUserId) {
    return _usersCol
        .doc(currentUserId)
        .collection(AppConstants.blockedSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
