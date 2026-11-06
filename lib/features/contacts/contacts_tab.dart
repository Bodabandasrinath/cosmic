import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../models/contact_model.dart';
import '../../models/follow_request_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
import '../../repositories/friendship_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';
import '../calls/active_voice_call_screen.dart';
import '../calls/active_video_call_screen.dart';
import '../chats/chat_screen.dart';
import 'user_search_screen.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final UserRepository _userRepository = UserRepository();
  final CallRepository _callRepository = CallRepository();
  final FriendshipRepository _friendshipRepository = FriendshipRepository();

  Future<void> _startCall(UserModel targetUser, CallType type) async {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final currentUser = authRepo.currentUser;
    if (currentUser == null) return;

    final areFriends = await _friendshipRepository.areFriends(currentUser.uid, targetUser.uid);
    if (!areFriends) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only accepted mutual friends can make voice and video calls.'),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
      return;
    }

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

  Widget _buildRequestsSection(List<FollowRequestModel> requests, String currentUserId) {
    if (requests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Follow Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.callRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ...requests.map((req) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  AvatarWidget(
                    name: req.senderDisplayName,
                    photoUrl: req.senderPhotoUrl,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.senderUsername.isNotEmpty ? req.senderUsername : req.senderDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          req.senderDisplayName,
                          style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.igBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await _friendshipRepository.acceptFollowRequest(req);
                    },
                    child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.callRed,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await _friendshipRepository.rejectFollowRequest(req);
                    },
                    child: const Text('Delete', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
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
          'Contacts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<FollowRequestModel>>(
        stream: _friendshipRepository.streamIncomingRequests(currentUserId),
        builder: (context, requestsSnapshot) {
          final requests = requestsSnapshot.data ?? [];

          return StreamBuilder<List<ContactModel>>(
            stream: _userRepository.streamContacts(currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && requestsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.igBlue));
              }

              final contacts = snapshot.data ?? [];

              if (contacts.isEmpty && requests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF262626), width: 1.5),
                          ),
                          child: const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF8E8E8E)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Friends Yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Follow people on Cosmic. Once they accept your follow request, you can exchange private messages and calls.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: Color(0xFF8E8E8E), height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UserSearchScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.igBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Discover People',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Incoming Requests Section
                  if (requests.isNotEmpty) _buildRequestsSection(requests, currentUserId),

                  if (contacts.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text(
                        'Mutual Friends',
                        style: TextStyle(
                          color: Color(0xFF8E8E8E),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...contacts.map((contact) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            AvatarWidget(
                              name: contact.displayName,
                              photoUrl: contact.profilePhoto,
                              radius: 24,
                              showStoryRing: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.username.isNotEmpty ? contact.username : contact.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    contact.displayName,
                                    style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            // Message button
                            GestureDetector(
                              onTap: () async {
                                final targetUser = await _userRepository.getUserById(contact.contactId);
                                if (targetUser != null && context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(otherUser: targetUser),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262626),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Message',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Voice Call
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              icon: const Icon(Icons.call_outlined, color: Colors.white70, size: 20),
                              onPressed: () async {
                                final targetUser = await _userRepository.getUserById(contact.contactId);
                                if (targetUser != null) {
                                  _startCall(targetUser, CallType.voice);
                                }
                              },
                            ),
                            // Video Call
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              icon: const Icon(Icons.videocam_outlined, color: Colors.white70, size: 22),
                              onPressed: () async {
                                final targetUser = await _userRepository.getUserById(contact.contactId);
                                if (targetUser != null) {
                                  _startCall(targetUser, CallType.video);
                                }
                              },
                            ),
                            // Remove connection
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              icon: const Icon(Icons.person_remove_outlined, color: Color(0xFF8E8E8E), size: 18),
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await _friendshipRepository.removeFriendship(
                                  currentUserId: currentUserId,
                                  targetUserId: contact.contactId,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Removed ${contact.displayName}')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
