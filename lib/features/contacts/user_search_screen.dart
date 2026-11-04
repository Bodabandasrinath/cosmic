import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';
import '../calls/active_voice_call_screen.dart';
import '../calls/active_video_call_screen.dart';
import '../chats/chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final UserRepository _userRepository = UserRepository();
  final CallRepository _callRepository = CallRepository();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;
    setState(() => _isLoading = true);

    try {
      final users = await _userRepository.searchUsers(clean, currentUserId: currentUserId);
      if (mounted) {
        setState(() {
          _results = users;
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    final currentUserId = Provider.of<AuthRepository>(context).currentUid!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          onChanged: _performSearch,
          decoration: InputDecoration(
            hintText: 'Search people by name, @username, or email...',
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryLight, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : (!_hasSearched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Icon(Icons.travel_explore_rounded, size: 36, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Find people on Cosmic',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Type a username to start a conversation or call',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : (_results.isEmpty
                  ? const Center(
                      child: Text(
                        'No users found matching your search.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      separatorBuilder: (_, __) => const Divider(
                        color: AppColors.cardBorder,
                        height: 1,
                        indent: 76,
                      ),
                      itemBuilder: (context, index) {
                        final user = _results[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: AvatarWidget(
                            name: user.displayName,
                            photoUrl: user.profilePhoto,
                            radius: 24,
                            isOnline: user.isOnline,
                            showOnlineIndicator: true,
                          ),
                          title: Text(
                            user.displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '@${user.username}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Add to contacts button
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryLight, size: 22),
                                onPressed: () async {
                                  await _userRepository.addContact(
                                    currentUserId: currentUserId,
                                    contactUser: user,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added ${user.displayName} to contacts')),
                                    );
                                  }
                                },
                              ),
                              // Message button
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.secondary, size: 22),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ChatScreen(otherUser: user)),
                                  );
                                },
                              ),
                              // Direct Voice Call 📞
                              IconButton(
                                icon: const Icon(Icons.call_rounded, color: AppColors.callGreen, size: 22),
                                onPressed: () => _startCall(user, CallType.voice),
                              ),
                            ],
                          ),
                        );
                      },
                    ))),
    );
  }
}
