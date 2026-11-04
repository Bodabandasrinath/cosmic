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

  /// 1. Create WebRTC Peer Connection with STUN servers
  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': AppConstants.iceServers,
      'sdpSemantics': 'unified-plan',
    };

    final offerSdpConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (kDebugMode) {
        print('WebRTC ICE Connection State: $state');
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        onCallStatusChanged?.call(CallStatus.connected);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                 state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        // Attempt reconnection or notify
        onCallStatusChanged?.call(CallStatus.failed);
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };
  }

  /// 2. Open Local User Media Stream (Mic / Camera)
  Future<void> _openUserMedia(CallType type) async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': type == CallType.video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
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

  /// 3. Caller: Start Outgoing Direct Call
  Future<void> startCall({required CallModel call}) async {
    await initializeRenderers();
    await _createPeerConnection();
    await _openUserMedia(call.type);

    final callDocRef = _firestore.collection(AppConstants.callsCollection).doc(call.callId);

    // Collect ICE Candidates from local peer and store to callerCandidates
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
      'status': CallStatus.calling.toShortString(),
    });

    // Listen to call doc for Answer and Status changes
    _callSubscription = callDocRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || _isDisposed) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final status = CallStatus.fromString(data['status'] ?? '');

      onCallStatusChanged?.call(status);

      // Receiver answered
      if (status == CallStatus.accepted || status == CallStatus.connected) {
        if (_peerConnection != null &&
            _peerConnection!.signalingState != RTCSignalingState.RTCSignalingStateStable &&
            data['sdpAnswer'] != null) {
          final answerMap = data['sdpAnswer'] as Map<String, dynamic>;
          final answer = RTCSessionDescription(answerMap['sdp'], answerMap['type']);
          await _peerConnection!.setRemoteDescription(answer);
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
        .listen((snapshot) {
      if (_peerConnection == null || _isDisposed) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  /// 4. Receiver: Accept Incoming Direct Call
  Future<void> acceptCall({required CallModel call}) async {
    await initializeRenderers();
    await _createPeerConnection();
    await _openUserMedia(call.type);

    final callDocRef = _firestore.collection(AppConstants.callsCollection).doc(call.callId);

    // Send Receiver ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && !_isDisposed) {
        callDocRef.collection(AppConstants.receiverCandidatesSubcollection).add(candidate.toMap());
      }
    };

    // Set Remote Description from Caller's Offer
    if (call.sdpOffer != null) {
      final offer = RTCSessionDescription(call.sdpOffer!['sdp'], call.sdpOffer!['type']);
      await _peerConnection!.setRemoteDescription(offer);
    } else {
      final doc = await callDocRef.get();
      final data = doc.data() as Map<String, dynamic>;
      final offerMap = data['sdpOffer'] as Map<String, dynamic>;
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerMap['sdp'], offerMap['type']),
      );
    }

    // Create SDP Answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Update Call document with Answer and status 'accepted'
    await callDocRef.update({
      'sdpAnswer': answer.toMap(),
      'status': CallStatus.accepted.toShortString(),
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    onCallStatusChanged?.call(CallStatus.connected);

    // Listen to Caller's ICE Candidates
    _candidatesSubscription = callDocRef
        .collection(AppConstants.callerCandidatesSubcollection)
        .snapshots()
        .listen((snapshot) {
      if (_peerConnection == null || _isDisposed) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
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
    } catch (_) {}
    dispose();
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
        Helper.switchCamera(videoTracks[0]);
        _isFrontCamera = !_isFrontCamera;
      }
    }
  }

  void setSpeakerphoneOn(bool enable) {
    _isSpeakerOn = enable;
    Helper.setSpeakerphoneOn(enable);
  }

  void toggleSpeaker() {
    setSpeakerphoneOn(!_isSpeakerOn);
  }

  void dispose() {
    _isDisposed = true;
    _callSubscription?.cancel();
    _candidatesSubscription?.cancel();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) => track.stop());
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
