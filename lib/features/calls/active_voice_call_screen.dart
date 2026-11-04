import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../repositories/call_repository.dart';
import '../../services/webrtc_service.dart';
import '../../widgets/avatar_widget.dart';
import 'active_video_call_screen.dart';

class ActiveVoiceCallScreen extends StatefulWidget {
  final CallModel call;
  final bool isCaller;

  const ActiveVoiceCallScreen({
    super.key,
    required this.call,
    required this.isCaller,
  });

  @override
  State<ActiveVoiceCallScreen> createState() => _ActiveVoiceCallScreenState();
}

class _ActiveVoiceCallScreenState extends State<ActiveVoiceCallScreen> with SingleTickerProviderStateMixin {
  final WebRTCService _webRTCService = WebRTCService();
  final CallRepository _callRepository = CallRepository();

  CallStatus _status = CallStatus.calling;
  int _durationSeconds = 0;
  Timer? _callTimer;
  Timer? _timeoutTimer;

  bool _isAudioMuted = false;
  bool _isSpeakerOn = false;

  late AnimationController _haloController;

  @override
  void initState() {
    super.initState();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

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
      // 45s Timeout for caller
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

  void _toggleSpeaker() {
    _webRTCService.toggleSpeaker();
    setState(() => _isSpeakerOn = _webRTCService.isSpeakerOn);
  }

  void _switchToVideo() {
    _webRTCService.dispose();
    _callTimer?.cancel();
    _timeoutTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveVideoCallScreen(
          call: widget.call.copyWith(type: CallType.video),
          isCaller: widget.isCaller,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _haloController.dispose();
    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _webRTCService.dispose();
    super.dispose();
  }

  String _getStatusText() {
    switch (_status) {
      case CallStatus.calling:
        return 'Calling...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connected:
        return DateFormatter.formatCallDuration(_durationSeconds);
      case CallStatus.failed:
        return 'Reconnecting...';
      default:
        return 'Call ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.isCaller ? widget.call.receiverName : widget.call.callerName;
    final photoUrl = widget.isCaller ? widget.call.receiverPhoto : widget.call.callerPhoto;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar: Minimize chevron & Encrypted Pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.igMutedGrey),
                        SizedBox(width: 6),
                        Text(
                          'End-to-end encrypted',
                          style: TextStyle(color: AppColors.igMutedGrey, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for back button
                ],
              ),
            ),

            // Instagram Center Avatar with Breathing Glow
            Column(
              children: [
                AnimatedBuilder(
                  animation: _haloController,
                  builder: (context, child) {
                    return Container(
                      padding: EdgeInsets.all(8 * _haloController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06 * _haloController.value),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.instagramStoryGradient,
                        ),
                        child: AvatarWidget(
                          name: displayName,
                          photoUrl: photoUrl,
                          radius: 68,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 15,
                    color: _status == CallStatus.connected ? const Color(0xFF00E676) : AppColors.igMutedGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Instagram Call Control Dock
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 24, right: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Mute
                    _buildDockButton(
                      icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: _isAudioMuted,
                      onTap: _toggleMute,
                    ),

                    // Speaker
                    _buildDockButton(
                      icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      isActive: _isSpeakerOn,
                      onTap: _toggleSpeaker,
                    ),

                    // Switch to Video
                    _buildDockButton(
                      icon: Icons.videocam_outlined,
                      isActive: false,
                      onTap: _switchToVideo,
                    ),

                    // End Call (Red Button)
                    GestureDetector(
                      onTap: () => _hangUp(endStatus: CallStatus.ended),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.callRed,
                          boxShadow: [
                            BoxShadow(color: Colors.black45, blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
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

  Widget _buildDockButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : const Color(0xFF2C2C2E),
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
