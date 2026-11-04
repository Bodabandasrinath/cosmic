import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../repositories/call_repository.dart';
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
  late AnimationController _pulseController;
  StreamSubscription<CallModel?>? _callStatusSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 40),

            // Caller Info & Pulsing Avatar
            Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: EdgeInsets.all(16 * _pulseController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isVideo ? AppColors.primary : AppColors.callGreen)
                            .withValues(alpha: 0.15 + (0.2 * _pulseController.value)),
                      ),
                      child: AvatarWidget(
                        name: widget.call.callerName,
                        photoUrl: widget.call.callerPhoto,
                        radius: 56,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  widget.call.callerName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam : Icons.call,
                      size: 18,
                      color: isVideo ? AppColors.primaryLight : AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVideo ? 'Incoming Video Call...' : 'Incoming Voice Call...',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Accept & Decline Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Decline
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
                            gradient: AppColors.endCallGradient,
                            boxShadow: [
                              BoxShadow(color: AppColors.callRed, blurRadius: 16, spreadRadius: 1),
                            ],
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Decline', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),

                  // Accept
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
                            gradient: AppColors.callGradient,
                            boxShadow: [
                              BoxShadow(color: AppColors.callGreen, blurRadius: 16, spreadRadius: 1),
                            ],
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Accept', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
