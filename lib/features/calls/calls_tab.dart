import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  final CallRepository _callRepository = CallRepository();
  final UserRepository _userRepository = UserRepository();

  Future<void> _redialCall({
    required UserModel targetUser,
    required CallType type,
  }) async {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final currentUser = authRepo.currentUser;
    if (currentUser == null) return;

    try {
      final call = await _callRepository.initiateDirectCall(
        caller: currentUser,
        receiver: targetUser,
        type: type,
      );

      if (mounted) {
        if (type == CallType.video) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActiveVideoCallScreen(call: call, isCaller: true),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActiveVoiceCallScreen(call: call, isCaller: true),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to call: $e'), backgroundColor: AppColors.callRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthRepository>(context).currentUid;
    if (currentUserId == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.igBlue));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Calls',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white, letterSpacing: -0.5),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _callRepository.streamCallLogs(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.igBlue));
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_missed_rounded, size: 36, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No call history yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Voice and video calls with friends will show here.',
                    style: TextStyle(fontSize: 13, color: AppColors.igMutedGrey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, index) {
              final log = logs[index];
              final isIncoming = log['isIncoming'] == true;
              final statusStr = log['status'] as String? ?? 'ended';
              final callStatus = CallStatus.fromString(statusStr);
              final typeStr = log['type'] as String? ?? 'voice';
              final callType = CallType.fromString(typeStr);

              final targetUserId = isIncoming ? (log['callerId'] ?? '') : (log['receiverId'] ?? '');
              final targetName = isIncoming ? (log['callerName'] ?? 'Cosmic User') : (log['receiverName'] ?? 'Cosmic User');
              final targetPhoto = isIncoming ? (log['callerPhoto'] ?? '') : (log['receiverPhoto'] ?? '');

              final rawTimestamp = log['timestamp'] ?? log['createdAt'];
              DateTime timestamp = DateTime.now();
              if (rawTimestamp is Timestamp) timestamp = rawTimestamp.toDate();

              final isMissed = callStatus == CallStatus.missed || (isIncoming && callStatus == CallStatus.rejected);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                leading: AvatarWidget(
                  name: targetName,
                  photoUrl: targetPhoto,
                  radius: 26,
                ),
                title: Text(
                  targetName,
                  style: TextStyle(
                    color: isMissed ? AppColors.callRed : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      isIncoming
                          ? (isMissed ? Icons.call_missed_rounded : Icons.call_received_rounded)
                          : Icons.call_made_rounded,
                      size: 14,
                      color: isMissed ? AppColors.callRed : (isIncoming ? const Color(0xFF00E676) : AppColors.igMutedGrey),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${isIncoming ? (isMissed ? 'Missed' : 'Incoming') : 'Outgoing'} · ${DateFormatter.formatChatListTime(timestamp)}',
                      style: const TextStyle(color: AppColors.igMutedGrey, fontSize: 13),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    callType == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () async {
                    final targetUser = await _userRepository.getUserById(targetUserId);
                    if (targetUser != null) {
                      _redialCall(targetUser: targetUser, type: callType);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
