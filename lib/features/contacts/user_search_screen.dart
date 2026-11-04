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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 38,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: _performSearch,
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E8E), size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Color(0xFF8E8E8E), size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.igBlue))
          : (!_hasSearched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF262626)),
                        ),
                        child: const Icon(Icons.search_rounded, size: 38, color: Color(0xFF8E8E8E)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Search Cosmic',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find people by name or @username to chat & call',
                        style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : (_results.isEmpty
                  ? const Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final user = _results[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              AvatarWidget(
                                name: user.displayName,
                                photoUrl: user.profilePhoto,
                                radius: 24,
                                isOnline: user.isOnline,
                                showOnlineIndicator: true,
                                showStoryRing: true,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username.isNotEmpty ? user.username : user.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              // Message button (Instagram Blue)
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ChatScreen(otherUser: user)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.igBlue,
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
                              // Audio call
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.call_outlined, color: Colors.white70, size: 20),
                                onPressed: () => _startCall(user, CallType.voice),
                              ),
                              // Video call
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.videocam_outlined, color: Colors.white70, size: 22),
                                onPressed: () => _startCall(user, CallType.video),
                              ),
                              // Add to contacts
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.person_add_outlined, color: Color(0xFF8E8E8E), size: 19),
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
                            ],
                          ),
                        );
                      },
                    ))),
    );
  }
}
