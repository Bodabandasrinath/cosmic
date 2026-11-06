import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/contact_model.dart';
import '../models/follow_request_model.dart';
import '../models/user_model.dart';

class FriendshipRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requestsCol =>
      _firestore.collection('follow_requests');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection(AppConstants.usersCollection);

  /// Helper to get deterministic request ID
  String getRequestId(String uid1, String uid2) => '${uid1}_$uid2';

  /// Send Follow/Friend Request
  Future<void> sendFollowRequest({
    required UserModel sender,
    required UserModel receiver,
  }) async {
    final requestId = getRequestId(sender.uid, receiver.uid);

    final request = FollowRequestModel(
      id: requestId,
      senderId: sender.uid,
      receiverId: receiver.uid,
      status: FollowRequestStatus.pending,
      senderUsername: sender.username,
      senderDisplayName: sender.displayName,
      senderPhotoUrl: sender.profilePhoto,
      receiverUsername: receiver.username,
      receiverDisplayName: receiver.displayName,
      receiverPhotoUrl: receiver.profilePhoto,
      createdAt: DateTime.now(),
    );

    await _requestsCol.doc(requestId).set(request.toMap());
  }

  /// Accept Follow/Friend Request
  Future<void> acceptFollowRequest(FollowRequestModel request) async {
    final batch = _firestore.batch();

    // 1. Update request status to accepted
    final reqRef = _requestsCol.doc(request.id);
    batch.update(reqRef, {
      'status': FollowRequestStatus.accepted.toShortString(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Add to following & followers for sender
    final senderFollowingRef = _usersCol
        .doc(request.senderId)
        .collection('following')
        .doc(request.receiverId);
    batch.set(senderFollowingRef, {
      'userId': request.receiverId,
      'username': request.receiverUsername,
      'displayName': request.receiverDisplayName,
      'profilePhoto': request.receiverPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final senderFollowersRef = _usersCol
        .doc(request.senderId)
        .collection('followers')
        .doc(request.receiverId);
    batch.set(senderFollowersRef, {
      'userId': request.receiverId,
      'username': request.receiverUsername,
      'displayName': request.receiverDisplayName,
      'profilePhoto': request.receiverPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Add to following & followers for receiver
    final receiverFollowingRef = _usersCol
        .doc(request.receiverId)
        .collection('following')
        .doc(request.senderId);
    batch.set(receiverFollowingRef, {
      'userId': request.senderId,
      'username': request.senderUsername,
      'displayName': request.senderDisplayName,
      'profilePhoto': request.senderPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final receiverFollowersRef = _usersCol
        .doc(request.receiverId)
        .collection('followers')
        .doc(request.senderId);
    batch.set(receiverFollowersRef, {
      'userId': request.senderId,
      'username': request.senderUsername,
      'displayName': request.senderDisplayName,
      'profilePhoto': request.senderPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Also add to contacts so contacts tab and stories remain synchronized
    final senderContact = ContactModel(
      contactId: request.receiverId,
      username: request.receiverUsername,
      displayName: request.receiverDisplayName,
      profilePhoto: request.receiverPhotoUrl,
      addedAt: DateTime.now(),
    );
    final receiverContact = ContactModel(
      contactId: request.senderId,
      username: request.senderUsername,
      displayName: request.senderDisplayName,
      profilePhoto: request.senderPhotoUrl,
      addedAt: DateTime.now(),
    );

    final senderContactRef = _usersCol
        .doc(request.senderId)
        .collection(AppConstants.contactsSubcollection)
        .doc(request.receiverId);
    batch.set(senderContactRef, senderContact.toMap());

    final receiverContactRef = _usersCol
        .doc(request.receiverId)
        .collection(AppConstants.contactsSubcollection)
        .doc(request.senderId);
    batch.set(receiverContactRef, receiverContact.toMap());

    await batch.commit();
  }

  /// Reject Follow/Friend Request
  Future<void> rejectFollowRequest(FollowRequestModel request) async {
    final batch = _firestore.batch();

    final reqRef = _requestsCol.doc(request.id);
    batch.update(reqRef, {
      'status': FollowRequestStatus.rejected.toShortString(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Clean up any mutual documents if previously connected
    batch.delete(_usersCol.doc(request.senderId).collection('following').doc(request.receiverId));
    batch.delete(_usersCol.doc(request.receiverId).collection('following').doc(request.senderId));
    batch.delete(_usersCol.doc(request.senderId).collection('followers').doc(request.receiverId));
    batch.delete(_usersCol.doc(request.receiverId).collection('followers').doc(request.senderId));
    batch.delete(_usersCol.doc(request.senderId).collection(AppConstants.contactsSubcollection).doc(request.receiverId));
    batch.delete(_usersCol.doc(request.receiverId).collection(AppConstants.contactsSubcollection).doc(request.senderId));

    await batch.commit();
  }

  /// Cancel an outgoing Follow Request
  Future<void> cancelFollowRequest({
    required String senderId,
    required String receiverId,
  }) async {
    final requestId = getRequestId(senderId, receiverId);
    await _requestsCol.doc(requestId).delete();
  }

  /// Remove friendship / unfollow
  Future<void> removeFriendship({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final batch = _firestore.batch();

    batch.delete(_usersCol.doc(currentUserId).collection('following').doc(targetUserId));
    batch.delete(_usersCol.doc(targetUserId).collection('following').doc(currentUserId));
    batch.delete(_usersCol.doc(currentUserId).collection('followers').doc(targetUserId));
    batch.delete(_usersCol.doc(targetUserId).collection('followers').doc(currentUserId));
    batch.delete(_usersCol.doc(currentUserId).collection(AppConstants.contactsSubcollection).doc(targetUserId));
    batch.delete(_usersCol.doc(targetUserId).collection(AppConstants.contactsSubcollection).doc(currentUserId));

    final req1 = _requestsCol.doc(getRequestId(currentUserId, targetUserId));
    batch.set(req1, {'status': FollowRequestStatus.rejected.toShortString(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    final req2 = _requestsCol.doc(getRequestId(targetUserId, currentUserId));
    batch.set(req2, {'status': FollowRequestStatus.rejected.toShortString(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await batch.commit();
  }

  /// Stream Incoming Pending Follow Requests for Current User
  Stream<List<FollowRequestModel>> streamIncomingRequests(String currentUserId) {
    return _requestsCol
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FollowRequestStatus.pending.toShortString())
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FollowRequestModel.fromDocument(doc)).toList());
  }

  /// Stream Outgoing Follow Requests sent by Current User
  Stream<List<FollowRequestModel>> streamOutgoingRequests(String currentUserId) {
    return _requestsCol
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FollowRequestStatus.pending.toShortString())
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FollowRequestModel.fromDocument(doc)).toList());
  }

  /// Stream Mutual Friendship Status with a specific user
  Stream<bool> streamAreFriends(String currentUserId, String otherUserId) {
    return _usersCol
        .doc(currentUserId)
        .collection('following')
        .doc(otherUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Check whether two users are mutual friends directly
  Future<bool> areFriends(String currentUserId, String otherUserId) async {
    final doc = await _usersCol
        .doc(currentUserId)
        .collection('following')
        .doc(otherUserId)
        .get();
    return doc.exists;
  }

  /// Get detailed relationship state between two users:
  /// 'friends' | 'pending_sent' | 'pending_received' | 'rejected' | 'none'
  Stream<String> streamRelationship(String currentUserId, String otherUserId) {
    // We listen to the following document and follow_requests
    final reqOutId = getRequestId(currentUserId, otherUserId);
    final reqInId = getRequestId(otherUserId, currentUserId);

    return _usersCol
        .doc(currentUserId)
        .collection('following')
        .doc(otherUserId)
        .snapshots()
        .asyncMap((followingDoc) async {
      if (followingDoc.exists) {
        return 'friends';
      }

      // Check outgoing request
      final outReq = await _requestsCol.doc(reqOutId).get();
      if (outReq.exists) {
        final status = outReq.data()?['status'] as String?;
        if (status == FollowRequestStatus.pending.toShortString()) return 'pending_sent';
        if (status == FollowRequestStatus.rejected.toShortString()) return 'rejected';
      }

      // Check incoming request
      final inReq = await _requestsCol.doc(reqInId).get();
      if (inReq.exists) {
        final status = inReq.data()?['status'] as String?;
        if (status == FollowRequestStatus.pending.toShortString()) return 'pending_received';
        if (status == FollowRequestStatus.rejected.toShortString()) return 'rejected';
      }

      return 'none';
    });
  }
}

