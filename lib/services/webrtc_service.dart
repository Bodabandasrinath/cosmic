import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/constants/app_constants.dart';
import '../models/call_model.dart';

class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  StreamSubscription<DocumentSnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _candidatesSubscription;

  // ICE Candidate queue to prevent premature candidate addition before setRemoteDescription
  final List<RTCIceCandidate> _queuedCandidates = [];
  bool _isRemoteDescriptionSet = false;

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  bool _isDisposed = false;

  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isFrontCamera => _isFrontCamera;

  Function(CallStatus status)? onCallStatusChanged;
  Function(String error)? onError;

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// 1. Create WebRTC Peer Connection with STUN and TURN servers
  Future<void> _createPeerConnection(CallType type) async {
    final configuration = <String, dynamic>{
      'iceServers': AppConstants.iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    final offerSdpConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': type == CallType.video,
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    // Monitor ICE Connection State
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (kDebugMode) {
        print('WebRTC ICE Connection State: $state');
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onCallStatusChanged?.call(CallStatus.connected);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        onCallStatusChanged?.call(CallStatus.failed);
      }
    };

    // Monitor Peer Connection State
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (kDebugMode) {
        print('WebRTC Peer Connection State: $state');
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallStatusChanged?.call(CallStatus.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onCallStatusChanged?.call(CallStatus.failed);
      }
    };

    // Listen for Remote Tracks (Unified Plan)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (_isDisposed) return;
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    // Fallback for legacy onAddStream
    _peerConnection!.onAddStream = (MediaStream stream) {
      if (_isDisposed) return;
      _remoteStream = stream;
      remoteRenderer.srcObject = _remoteStream;
    };
  }

  /// 2. Open Local User Media Stream (Mic / Camera)
  Future<void> _openUserMedia(CallType type) async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': type == CallType.video
          ? (kIsWeb
              ? {'facingMode': 'user'}
              : {
                  'mandatory': {
                    'minWidth': '640',
                    'minHeight': '480',
                    'minFrameRate': '30',
                  },
                  'facingMode': 'user',
                  'optional': [],
                })
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;

      if (_localStream != null && _peerConnection != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      // Default audio routing: speaker for video call, earpiece for voice call
      if (type == CallType.video) {
        setSpeakerphoneOn(true);
      } else {
        setSpeakerphoneOn(false);
      }
    } catch (e) {
      onError?.call('Unable to access camera or microphone: $e');
      rethrow;
    }
  }

  /// Flush any ICE candidates received prior to setRemoteDescription
  Future<void> _drainCandidateQueue() async {
    if (_peerConnection == null || !_isRemoteDescriptionSet) return;
    while (_queuedCandidates.isNotEmpty) {
      final cand = _queuedCandidates.removeAt(0);
      try {
        await _peerConnection!.addCandidate(cand);
      } catch (e) {
        if (kDebugMode) print('Error draining candidate: $e');
      }
    }
  }

  /// 3. Caller: Start Outgoing Direct Call
  Future<void> startCall({required CallModel call}) async {
    await initializeRenderers();
    await _createPeerConnection(call.type);
    await _openUserMedia(call.type);

    final callDocRef = _firestore.collection(AppConstants.callsCollection).doc(call.callId);

    // Send Local ICE Candidates to Firestore
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && !_isDisposed) {
        callDocRef.collection(AppConstants.callerCandidatesSubcollection).add(candidate.toMap());
      }
    };

    // Create SDP Offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Save Offer in call document
    await callDocRef.set({
      ...call.toMap(),
      'sdpOffer': offer.toMap(),
      'offer': offer.toMap(),
      'status': CallStatus.calling.toShortString(),
    }, SetOptions(merge: true));

    // Listen to call doc for Answer and Status changes
    _callSubscription = callDocRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || _isDisposed) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final status = CallStatus.fromString(data['status'] ?? '');

      onCallStatusChanged?.call(status);

      // Receiver answered
      if (status == CallStatus.accepted || status == CallStatus.connected) {
        final answerMap = (data['sdpAnswer'] ?? data['answer']) as Map<String, dynamic>?;
        if (_peerConnection != null &&
            _peerConnection!.signalingState != RTCSignalingState.RTCSignalingStateStable &&
            answerMap != null) {
          final answer = RTCSessionDescription(
            answerMap['sdp'] as String? ?? '',
            answerMap['type'] as String? ?? 'answer',
          );
          await _peerConnection!.setRemoteDescription(answer);
          _isRemoteDescriptionSet = true;
          await _drainCandidateQueue();
        }
      } else if (status == CallStatus.rejected ||
                 status == CallStatus.busy ||
                 status == CallStatus.ended ||
                 status == CallStatus.missed) {
        endCall(callId: call.callId, endStatus: status);
      }
    });

    // Listen to Receiver's ICE Candidates
    _candidatesSubscription = callDocRef
        .collection(AppConstants.receiverCandidatesSubcollection)
        .snapshots()
        .listen((snapshot) async {
      if (_peerConnection == null || _isDisposed) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          if (_isRemoteDescriptionSet) {
            try {
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              if (kDebugMode) print('addCandidate error: $e');
            }
          } else {
            _queuedCandidates.add(candidate);
          }
        }
      }
    });
  }

  /// 4. Receiver: Accept Incoming Direct Call
  Future<void> acceptCall({required CallModel call}) async {
    await initializeRenderers();
    await _createPeerConnection(call.type);
    await _openUserMedia(call.type);

    final callDocRef = _firestore.collection(AppConstants.callsCollection).doc(call.callId);

    // Send Receiver ICE candidates to Firestore
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && !_isDisposed) {
        callDocRef.collection(AppConstants.receiverCandidatesSubcollection).add(candidate.toMap());
      }
    };

    // Set Remote Description from Caller's Offer
    Map<String, dynamic>? offerMap = call.sdpOffer;
    if (offerMap == null) {
      final doc = await callDocRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        offerMap = (data['sdpOffer'] ?? data['offer']) as Map<String, dynamic>?;
      }
    }

    if (offerMap != null) {
      final offer = RTCSessionDescription(
        offerMap['sdp'] as String? ?? '',
        offerMap['type'] as String? ?? 'offer',
      );
      await _peerConnection!.setRemoteDescription(offer);
      _isRemoteDescriptionSet = true;
      await _drainCandidateQueue();
    }

    // Create SDP Answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Update Call document with Answer and status 'accepted'
    await callDocRef.update({
      'sdpAnswer': answer.toMap(),
      'answer': answer.toMap(),
      'status': CallStatus.accepted.toShortString(),
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    onCallStatusChanged?.call(CallStatus.connected);

    // Listen to Caller's ICE Candidates
    _candidatesSubscription = callDocRef
        .collection(AppConstants.callerCandidatesSubcollection)
        .snapshots()
        .listen((snapshot) async {
      if (_peerConnection == null || _isDisposed) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          if (_isRemoteDescriptionSet) {
            try {
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              if (kDebugMode) print('addCandidate error: $e');
            }
          } else {
            _queuedCandidates.add(candidate);
          }
        }
      }
    });

    // Listen to call state changes (e.g. ended by caller)
    _callSubscription = callDocRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || _isDisposed) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final status = CallStatus.fromString(data['status'] ?? '');
      if (status == CallStatus.ended || status == CallStatus.rejected) {
        endCall(callId: call.callId, endStatus: status);
      }
    });
  }

  /// 5. Reject Incoming Call
  Future<void> rejectCall({required String callId, CallStatus status = CallStatus.rejected}) async {
    try {
      await _firestore.collection(AppConstants.callsCollection).doc(callId).update({
        'status': status.toShortString(),
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    dispose();
  }

  /// 6. End Active Call
  Future<void> endCall({required String callId, CallStatus endStatus = CallStatus.ended, int durationSeconds = 0}) async {
    try {
      await _firestore.collection(AppConstants.callsCollection).doc(callId).update({
        'status': endStatus.toShortString(),
        'endedAt': FieldValue.serverTimestamp(),
        'durationSeconds': durationSeconds,
      });
      await _cleanupSignaling(callId);
    } catch (_) {}
    dispose();
  }

  /// Clean up candidate signaling subcollections to preserve database storage & privacy
  Future<void> _cleanupSignaling(String callId) async {
    try {
      final callDocRef = _firestore.collection(AppConstants.callsCollection).doc(callId);
      final callerCands = await callDocRef.collection(AppConstants.callerCandidatesSubcollection).get();
      for (final doc in callerCands.docs) {
        await doc.reference.delete();
      }
      final receiverCands = await callDocRef.collection(AppConstants.receiverCandidatesSubcollection).get();
      for (final doc in receiverCands.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  /// Media Controls
  void toggleMuteAudio() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        _isAudioMuted = !_isAudioMuted;
        audioTracks[0].enabled = !_isAudioMuted;
      }
    }
  }

  void toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        _isVideoMuted = !_isVideoMuted;
        videoTracks[0].enabled = !_isVideoMuted;
      }
    }
  }

  void switchCamera() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        try {
          Helper.switchCamera(videoTracks[0]);
          _isFrontCamera = !_isFrontCamera;
        } catch (e) {
          if (kDebugMode) print('switchCamera error: $e');
        }
      }
    }
  }

  void setSpeakerphoneOn(bool enable) {
    _isSpeakerOn = enable;
    if (!kIsWeb) {
      try {
        Helper.setSpeakerphoneOn(enable);
      } catch (e) {
        if (kDebugMode) print('Helper.setSpeakerphoneOn error: $e');
      }
    }
  }

  void toggleSpeaker() {
    setSpeakerphoneOn(!_isSpeakerOn);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _callSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _queuedCandidates.clear();

    _localStream?.getTracks().forEach((track) {
      try {
        track.stop();
      } catch (_) {}
    });
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) {
      try {
        track.stop();
      } catch (_) {}
    });
    _remoteStream?.dispose();
    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    localRenderer.dispose();
    remoteRenderer.dispose();
  }
}
