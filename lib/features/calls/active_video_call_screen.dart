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
  bool _showControls = true;

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
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // 1. Remote Video (Full Screen Edge-to-Edge)
            Positioned.fill(
              child: _status == CallStatus.connected && _webRTCService.remoteRenderer.srcObject != null
                  ? RTCVideoView(
                      _webRTCService.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: const Color(0xFF121212),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF262626),
                              ),
                              child: const Icon(Icons.videocam_rounded, size: 56, color: Colors.white),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _status == CallStatus.calling
                                  ? 'Calling $displayName...'
                                  : (_status == CallStatus.ringing ? 'Ringing...' : 'Connecting video...'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // 2. Draggable PIP Camera Preview (Instagram Style)
            Positioned(
              left: _pipPosition.dx,
              top: _pipPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pipPosition = Offset(
                      (_pipPosition.dx + details.delta.dx).clamp(10.0, size.width - 125),
                      (_pipPosition.dy + details.delta.dy).clamp(40.0, size.height - 195),
                    );
                  });
                },
                child: Container(
                  width: 110,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 12),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: !_isVideoMuted && _webRTCService.localRenderer.srcObject != null
                        ? RTCVideoView(
                            _webRTCService.localRenderer,
                            mirror: _webRTCService.isFrontCamera,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        : Container(
                            color: const Color(0xFF262626),
                            child: const Center(
                              child: Icon(Icons.videocam_off, color: Colors.white54, size: 28),
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // 3. Instagram Video Call Top Bar
            if (_showControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _status == CallStatus.connected ? const Color(0xFF00E676) : AppColors.callAmber,
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
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // 4. Instagram Video Call Bottom Control Dock
            if (_showControls)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Flip Camera
                      _buildControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        isActive: false,
                        onTap: _switchCamera,
                      ),

                      // Video On/Off
                      _buildControlButton(
                        icon: _isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        isActive: _isVideoMuted,
                        onTap: _toggleVideo,
                      ),

                      // Mic Mute
                      _buildControlButton(
                        icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        isActive: _isAudioMuted,
                        onTap: _toggleMute,
                      ),

                      // Speaker
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        isActive: _isSpeakerOn,
                        onTap: _toggleSpeaker,
                      ),

                      // End Call (Red Button)
                      GestureDetector(
                        onTap: () => _hangUp(endStatus: CallStatus.ended),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.callRed,
                            boxShadow: [
                              BoxShadow(color: Colors.black45, blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
          color: isActive ? Colors.white : const Color(0xFF2C2C2E),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
