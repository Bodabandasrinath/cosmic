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
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contacts', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppColors.primaryLight),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ContactModel>>(
        stream: _userRepository.streamContacts(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
          }

          final contacts = snapshot.data ?? [];
          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 38, color: AppColors.primaryLight),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No contacts added yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Search for users on Cosmic to add them',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Discover People'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UserSearchScreen()),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: contacts.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) => const Divider(
              color: AppColors.cardBorder,
              height: 1,
              indent: 76,
            ),
            itemBuilder: (context, index) {
              final contact = contacts[index];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: AvatarWidget(
                  name: contact.displayName,
                  photoUrl: contact.profilePhoto,
                  radius: 24,
                ),
                title: Text(
                  contact.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '@${contact.username}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start Chat
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryLight, size: 22),
                      onPressed: () async {
                        final targetUser = await _userRepository.getUserById(contact.contactId);
                        if (targetUser != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(otherUser: targetUser),
                            ),
                          );
                        }
                      },
                    ),
                    // Voice Call 📞
                    IconButton(
                      icon: const Icon(Icons.call_rounded, color: AppColors.secondary, size: 22),
                      onPressed: () async {
                        final targetUser = await _userRepository.getUserById(contact.contactId);
                        if (targetUser != null) {
                          _startCall(targetUser, CallType.voice);
                        }
                      },
                    ),
                    // Video Call 🎥
                    IconButton(
                      icon: const Icon(Icons.videocam_rounded, color: AppColors.accentPink, size: 22),
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
