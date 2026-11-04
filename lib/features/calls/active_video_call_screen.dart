import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../repositories/call_repository.dart';
import '../../services/webrtc_service.dart';

class ActiveVideoCallScreen extends StatefulWidget {
  final CallModel call;
  final bool isCaller;

  const ActiveVideoCallScreen({
    super.key,
    required this.call,
    required this.isCaller,
  });

  @override
  State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final CallRepository _callRepository = CallRepository();

  CallStatus _status = CallStatus.calling;
  int _durationSeconds = 0;
  Timer? _callTimer;
  Timer? _timeoutTimer;

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isSpeakerOn = true;

  // Draggable PIP coordinates
  Offset _pipPosition = const Offset(20, 80);

  @override
  void initState() {
    super.initState();
    _startWebRTC();
  }

  Future<void> _startWebRTC() async {
    _webRTCService.onCallStatusChanged = (status) {
      if (!mounted) return;
      setState(() => _status = status);

      if (status == CallStatus.connected && _callTimer == null) {
        _timeoutTimer?.cancel();
        _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _durationSeconds++);
        });
      } else if (status == CallStatus.ended ||
                 status == CallStatus.rejected ||
                 status == CallStatus.busy ||
                 status == CallStatus.missed) {
        _endCallUI();
      }
    };

    _webRTCService.onError = (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.callRed),
        );
      }
    };

    if (widget.isCaller) {
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (_status != CallStatus.connected) {
          _hangUp(endStatus: CallStatus.missed);
        }
      });
      await _webRTCService.startCall(call: widget.call);
    } else {
      await _webRTCService.acceptCall(call: widget.call);
    }
  }

  void _hangUp({CallStatus endStatus = CallStatus.ended}) async {
    _callTimer?.cancel();
    _timeoutTimer?.cancel();

    await _webRTCService.endCall(
      callId: widget.call.callId,
      endStatus: endStatus,
      durationSeconds: _durationSeconds,
    );

    await _callRepository.updateCallLogStatus(
      callId: widget.call.callId,
      currentUserId: widget.isCaller ? widget.call.callerId : widget.call.receiverId,
      status: endStatus,
      durationSeconds: _durationSeconds,
    );

    _endCallUI();
  }

  void _endCallUI() {
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    _webRTCService.toggleMuteAudio();
    setState(() => _isAudioMuted = _webRTCService.isAudioMuted);
  }

  void _toggleVideo() {
    _webRTCService.toggleVideo();
    setState(() => _isVideoMuted = _webRTCService.isVideoMuted);
  }

  void _switchCamera() {
    _webRTCService.switchCamera();
  }

  void _toggleSpeaker() {
    _webRTCService.toggleSpeaker();
    setState(() => _isSpeakerOn = _webRTCService.isSpeakerOn);
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _webRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.isCaller ? widget.call.receiverName : widget.call.callerName;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Remote Video (Full Screen)
          Positioned.fill(
            child: _status == CallStatus.connected && _webRTCService.remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _webRTCService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: AppColors.background,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, size: 64, color: AppColors.primaryLight),
                          const SizedBox(height: 16),
                          Text(
                            _status == CallStatus.calling
                                ? 'Calling $displayName...'
                                : (_status == CallStatus.ringing ? 'Ringing...' : 'Connecting video...'),
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Draggable Local Camera Preview (PIP)
          Positioned(
            left: _pipPosition.dx,
            top: _pipPosition.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _pipPosition = Offset(
                    (_pipPosition.dx + details.delta.dx).clamp(10.0, size.width - 130),
                    (_pipPosition.dy + details.delta.dy).clamp(40.0, size.height - 200),
                  );
                });
              },
              child: Container(
                width: 110,
                height: 155,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: !_isVideoMuted && _webRTCService.localRenderer.srcObject != null
                      ? RTCVideoView(
                          _webRTCService.localRenderer,
                          mirror: _webRTCService.isFrontCamera,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.videocam_off, color: Colors.white54, size: 28),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // 3. Top Call Info Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _status == CallStatus.connected ? AppColors.online : AppColors.callAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _status == CallStatus.connected
                            ? DateFormatter.formatCallDuration(_durationSeconds)
                            : (_status == CallStatus.calling ? 'Calling...' : 'Ringing...'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // 4. Video Call Bottom Action Controls (🎤 📹 🔊 🔄 🔴)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Microphone mute/unmute
                  _buildControlButton(
                    icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                    isActive: _isAudioMuted,
                    onTap: _toggleMute,
                  ),

                  // Camera on/off
                  _buildControlButton(
                    icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                    isActive: _isVideoMuted,
                    onTap: _toggleVideo,
                  ),

                  // Speakerphone
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    isActive: _isSpeakerOn,
                    onTap: _toggleSpeaker,
                  ),

                  // Switch Camera (Front / Back)
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    isActive: false,
                    onTap: _switchCamera,
                  ),

                  // End Call (Red Button)
                  GestureDetector(
                    onTap: () => _hangUp(endStatus: CallStatus.ended),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.endCallGradient,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : Colors.white12,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
