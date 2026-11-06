import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../repositories/call_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../widgets/avatar_widget.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  final CallRepository _callRepository = CallRepository();
  final ChatRepository _chatRepository = ChatRepository();
  late AnimationController _pulseController;
  StreamSubscription<CallModel?>? _callStatusSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Listen to call doc: if caller cancels, dismiss
    _callStatusSub = _callRepository.streamCall(widget.call.callId).listen((updatedCall) {
      if (updatedCall == null ||
          updatedCall.status == CallStatus.ended ||
          updatedCall.status == CallStatus.missed ||
          updatedCall.status == CallStatus.rejected) {
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _callStatusSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _declineCall() async {
    await _callRepository.rejectCall(
      widget.call.callId,
      receiverId: widget.call.receiverId,
      status: CallStatus.rejected,
    );
    await _chatRepository.saveCallEventMessage(
      callerId: widget.call.callerId,
      receiverId: widget.call.receiverId,
      callType: widget.call.type.toShortString(),
      callStatus: 'rejected',
      callId: widget.call.callId,
      startedAt: widget.call.createdAt,
      endedAt: DateTime.now(),
      durationSeconds: 0,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _acceptCall() {
    _callStatusSub?.cancel();
    if (widget.call.type == CallType.video) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveVideoCallScreen(call: widget.call, isCaller: false),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveVoiceCallScreen(call: widget.call, isCaller: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == CallType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar with Encryption Pill
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
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
            ),

            // Instagram Caller Info & Pulsing Concentric Rings
            Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsing Ring
                        Container(
                          width: 170 + (40 * _pulseController.value),
                          height: 170 + (40 * _pulseController.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isVideo ? AppColors.igBlue : AppColors.callGreen)
                                  .withValues(alpha: 0.25 * (1.0 - _pulseController.value)),
                              width: 2,
                            ),
                          ),
                        ),
                        // Middle Pulsing Ring
                        Container(
                          width: 140 + (25 * _pulseController.value),
                          height: 140 + (25 * _pulseController.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isVideo ? AppColors.igBlue : AppColors.callGreen)
                                .withValues(alpha: 0.12 * _pulseController.value),
                          ),
                        ),
                        // Center Avatar with Instagram Story Gradient Ring
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.instagramStoryGradient,
                          ),
                          child: AvatarWidget(
                            name: widget.call.callerName,
                            photoUrl: widget.call.callerPhoto,
                            radius: 54,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  widget.call.callerName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideo ? 'Cosmic Video Call...' : 'Cosmic Audio Call...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.igMutedGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Instagram Call Action Buttons (Decline / Accept)
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0, left: 48, right: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _declineCall,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.callRed,
                            boxShadow: [
                              BoxShadow(color: Colors.black45, blurRadius: 16),
                            ],
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Decline',
                        style: TextStyle(color: AppColors.igMutedGrey, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  // Accept Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _acceptCall,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00E676),
                            boxShadow: [
                              BoxShadow(color: Colors.black45, blurRadius: 16),
                            ],
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

