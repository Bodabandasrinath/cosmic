import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import 'chat_repository.dart';

class CallRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Create and initiate a direct 1-to-1 call (User never sees or enters any Room ID)
  Future<CallModel> initiateDirectCall({
    required UserModel caller,
    required UserModel receiver,
    required CallType type,
  }) async {
    // 1. Verify mutual friendship before initiating call
    final friendDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(caller.uid)
        .collection('following')
        .doc(receiver.uid)
        .get();

    if (!friendDoc.exists) {
      throw 'Only accepted mutual friends can make voice and video calls.';
    }

    // Check if there is already an active session between caller and receiver
    try {
      final activeSnap = await _firestore
          .collection(AppConstants.callsCollection)
          .where('callerId', isEqualTo: caller.uid)
          .where('receiverId', isEqualTo: receiver.uid)
          .where('status', whereIn: [
            CallStatus.calling.toShortString(),
            CallStatus.ringing.toShortString(),
            CallStatus.accepted.toShortString(),
            CallStatus.connected.toShortString(),
          ])
          .limit(1)
          .get();

      if (activeSnap.docs.isNotEmpty) {
        throw 'A call is already in progress with this user';
      }
    } catch (e) {
      if (e.toString().contains('already in progress')) {
        rethrow;
      }
    }

    // Generate technical internal session ID
    final internalCallId = _uuid.v4();

    final call = CallModel(
      callId: internalCallId,
      callerId: caller.uid,
      receiverId: receiver.uid,
      callerName: caller.displayName,
      callerPhoto: caller.profilePhoto,
      receiverName: receiver.displayName,
      receiverPhoto: receiver.profilePhoto,
      type: type,
      status: CallStatus.calling,
      createdAt: DateTime.now(),
    );

    // Save call document to Firestore for signaling
    await _firestore
        .collection(AppConstants.callsCollection)
        .doc(internalCallId)
        .set(call.toMap());

    // Record in Caller's Call History
    await _recordCallLog(
      userId: caller.uid,
      call: call,
      isIncoming: false,
    );

    // Record in Receiver's Call History
    await _recordCallLog(
      userId: receiver.uid,
      call: call,
      isIncoming: true,
    );

    return call;
  }

  /// Reject incoming call and update caller & log
  Future<void> rejectCall(
    String callId, {
    required String receiverId,
    CallStatus status = CallStatus.rejected,
  }) async {
    try {
      final callRef = _firestore.collection(AppConstants.callsCollection).doc(callId);
      final callDoc = await callRef.get();
      await callRef.update({
        'status': status.toShortString(),
        'endedAt': FieldValue.serverTimestamp(),
      });
      await updateCallLogStatus(
        callId: callId,
        currentUserId: receiverId,
        status: status,
      );

      if (callDoc.exists) {
        final data = callDoc.data()!;
        final callerId = data['callerId'] ?? '';
        final type = data['type'] ?? 'voice';
        final statusStr = status == CallStatus.busy ? 'missed' : 'rejected';
        ChatRepository().saveCallEventMessage(
          callerId: callerId,
          receiverId: receiverId,
          callType: type,
          callStatus: statusStr,
          callId: callId,
          startedAt: (data['createdAt'] as Timestamp?)?.toDate(),
          endedAt: DateTime.now(),
          durationSeconds: 0,
        );
      }
    } catch (_) {}
  }

  /// Clean up call signaling documents and ICE candidate subcollections
  Future<void> cleanupCallSignaling(String callId) async {
    try {
      final callRef = _firestore.collection(AppConstants.callsCollection).doc(callId);
      final callerCands = await callRef.collection(AppConstants.callerCandidatesSubcollection).get();
      for (final doc in callerCands.docs) {
        await doc.reference.delete();
      }
      final receiverCands = await callRef.collection(AppConstants.receiverCandidatesSubcollection).get();
      for (final doc in receiverCands.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  /// Listen for incoming calls for the current user in real-time
  Stream<CallModel?> streamIncomingCalls(String currentUserId) {
    return _firestore
        .collection(AppConstants.callsCollection)
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: CallStatus.calling.toShortString())
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      // Return the most recent calling document
      final doc = snapshot.docs.first;
      return CallModel.fromDocument(doc);
    });
  }

  /// Listen to an ongoing call session
  Stream<CallModel?> streamCall(String callId) {
    return _firestore
        .collection(AppConstants.callsCollection)
        .doc(callId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return CallModel.fromDocument(doc);
    });
  }

  /// Record entry in call history log
  Future<void> _recordCallLog({
    required String userId,
    required CallModel call,
    required bool isIncoming,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.callLogsCollection)
          .doc(userId)
          .collection('logs')
          .doc(call.callId)
          .set({
        ...call.toMap(),
        'isIncoming': isIncoming,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Update call history status (e.g. ended, duration, missed)
  Future<void> updateCallLogStatus({
    required String callId,
    required String currentUserId,
    required CallStatus status,
    int durationSeconds = 0,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.callLogsCollection)
          .doc(currentUserId)
          .collection('logs')
          .doc(callId)
          .update({
        'status': status.toShortString(),
        'durationSeconds': durationSeconds,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Stream user's call history
  Stream<List<Map<String, dynamic>>> streamCallLogs(String currentUserId) {
    return _firestore
        .collection(AppConstants.callLogsCollection)
        .doc(currentUserId)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}


