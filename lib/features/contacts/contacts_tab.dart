import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../models/contact_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
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

  Future<void> _startCall(UserModel targetUser, CallType type) async {
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
      body: StreamBuilder<List<ContactModel>>(
        stream: _userRepository.streamContacts(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.igBlue));
          }

          final contacts = snapshot.data ?? [];
          if (contacts.isEmpty) {
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
                      'No Contacts Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Search for people on Cosmic to start direct chats, voice calls, and video calls.',
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

          return ListView.builder(
            itemCount: contacts.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final contact = contacts[index];

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
                    const SizedBox(width: 8),
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
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
