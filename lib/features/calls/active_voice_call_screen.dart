import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../repositories/call_repository.dart';
import '../../services/webrtc_service.dart';
import '../../widgets/avatar_widget.dart';

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

class _ActiveVoiceCallScreenState extends State<ActiveVoiceCallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final CallRepository _callRepository = CallRepository();

  CallStatus _status = CallStatus.calling;
  int _durationSeconds = 0;
  Timer? _callTimer;
  Timer? _timeoutTimer;

  bool _isAudioMuted = false;
  bool _isSpeakerOn = false;

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

  @override
  void dispose() {
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: AppColors.online),
                        SizedBox(width: 4),
                        Text('End-to-End Encrypted', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Profile info & Avatar
            Column(
              children: [
                AvatarWidget(
                  name: displayName,
                  photoUrl: photoUrl,
                  radius: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 16,
                    color: _status == CallStatus.connected ? AppColors.online : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 32, right: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _buildCallAction(
                    icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isAudioMuted ? 'Unmute' : 'Mute',
                    isActive: _isAudioMuted,
                    onTap: _toggleMute,
                  ),

                  // End Call (Big Red Button)
                  GestureDetector(
                    onTap: () => _hangUp(endStatus: CallStatus.ended),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.endCallGradient,
                        boxShadow: [
                          BoxShadow(color: AppColors.callRed, blurRadius: 16, spreadRadius: 1),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                    ),
                  ),

                  // Speaker
                  _buildCallAction(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallAction({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : AppColors.surface,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
